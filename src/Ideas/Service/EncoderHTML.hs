{-# LANGUAGE GADTs #-}
-----------------------------------------------------------------------------
-- Copyright 2011, Open Universiteit Nederland. This file is distributed
-- under the terms of the GNU General Public License. For more information,
-- see the file "LICENSE.txt", which is included in the distribution.
-----------------------------------------------------------------------------
-- |
-- Maintainer  :  bastiaan.heeren@ou.nl
-- Stability   :  provisional
-- Portability :  portable (depends on ghc)
--
-- Services using XML notation
--
-----------------------------------------------------------------------------
module Ideas.Service.EncoderHTML (htmlEncoder) where

import Ideas.Common.Utils
import Control.Monad
import Data.Char
import Data.List
import Data.Maybe
import Ideas.Common.Library hiding (ready)
import Ideas.Documentation.RulePresenter
import Ideas.Text.XML
import Ideas.Text.HTML
import Ideas.Service.DomainReasoner
import Ideas.Service.Evaluator
import Ideas.Service.State
import Ideas.Service.Types
import Ideas.Service.EncoderXML
import Ideas.Service.BasicServices

htmlEncoder :: DomainReasoner -> Exercise a -> TypedValue (Type a) -> HTML
htmlEncoder dr ex tv = htmlPage "EncoderHTML" (Just "ideas.css") $ do
   divClass "content" $
      encodeType ex tv
   divClass "footer" $
      text (fullVersion dr)

encodeType :: Exercise a -> Encoder (Type a) XMLBuilderM ()
encodeType ex (val ::: tp) = 
   case tp of 
      Iso iso t  -> encodeType ex (to iso val ::: t)
      Tag _ t    -> encodeType ex (val ::: t)
      Pair t1 t2 -> do encodeType ex (fst val ::: t1)
                       br
                       encodeType ex (snd val ::: t2)
      t1 :|: t2  -> case val of
                       Left x  -> encodeType ex (x ::: t1)
                       Right x -> encodeType ex (x ::: t2)
      List (Const SomeExercise) -> encodeExerciseList val
      List (Tag "RuleShortInfo" (Iso iso (Const Rule))) -> encodeRuleList ex (map (to iso) val)
      List t     -> ul [ encodeType ex (x ::: t) | x <- val ]
      Const t    -> encodeConst ex (val ::: t)
      _ -> text $ "unknown: " ++ show tp
      
encodeConst :: Exercise a -> Encoder (Const a) XMLBuilderM ()
encodeConst ex tv@(val ::: tp) =
   case tp of 
      Exercise     -> encodeExercise val
      Rule         -> text $ "ruleid: " ++ showId val
      Derivation t1 t2 -> htmlDerivation ex t1 t2 val
      SomeExercise -> case val of
                         Some ex -> text $ "exerciseid: " ++ showId ex
      Context      -> do h2 " context" 
                         htmlState (empyStateContext ex val)
      Location     -> text $ "location: " ++ show val
      Environment  -> text $ "environment: " ++ show val
      State        -> htmlState val
      String       -> text val
      _ -> text $ show tv

data LinkManager a = LinkManager
   { {- mainUrl         :: String
   , urlForServices  :: String
   , urlForService   :: Service -> String
   , urlForExercises :: String -}
     urlForExercise   :: Exercise a -> String
   , urlForExamples   :: Exercise a  -> String
   , urlForRandomExample :: Difficulty -> Exercise a -> String
   --, urlForStrategy  :: Exercise a -> String
   --, urlForRules     :: Exercise a -> String
--   , urlForRule      :: Exercise a -> Rule (Context a) -> String
   , urlForState      :: State a -> String
   , urlForAllFirsts  :: State a -> String
   , urlForAllApplications :: State a -> String
   , urlForDerivation :: State a -> String
   }
   
linkToExercise :: LinkManager a -> Exercise a -> HTMLBuilder -> HTMLBuilder
linkToExercise lm = link . escapeInURL . urlForExercise lm
   
linkToExamples :: LinkManager a -> Exercise a -> HTMLBuilder -> HTMLBuilder
linkToExamples lm = link . escapeInURL . urlForExamples lm
   
linkToRandomExample :: LinkManager a -> Difficulty -> Exercise a -> HTMLBuilder -> HTMLBuilder
linkToRandomExample lm d = link . escapeInURL . urlForRandomExample lm d
   
linkToState :: LinkManager a -> State a -> HTMLBuilder -> HTMLBuilder
linkToState lm = link . escapeInURL . urlForState lm
   
linkToAllFirsts :: LinkManager a -> State a -> HTMLBuilder -> HTMLBuilder
linkToAllFirsts lm = link . escapeInURL . urlForAllFirsts lm

linkToAllApplications :: LinkManager a -> State a -> HTMLBuilder -> HTMLBuilder
linkToAllApplications lm = link . escapeInURL . urlForAllApplications lm

linkToDerivation :: LinkManager a -> State a -> HTMLBuilder -> HTMLBuilder
linkToDerivation lm = link . escapeInURL . urlForDerivation lm

lm :: LinkManager a
lm = LinkManager 
   { urlForExercise = \ex ->
        -- url ++ show (exampleRequest ex)
        url ++ show (exerciseInfoRequest ex)
   , urlForExamples = \ex ->
        url ++ show (examplesRequest ex)
   , urlForRandomExample = \d ex ->
        url ++ show (generateRequest d ex)
   , urlForState = \state -> 
        url ++ show (stateInfoRequest state)
   , urlForAllFirsts = \state ->
        url ++ show (allFirstsRequest state)
   , urlForAllApplications = \state -> 
        url ++ show (allApplicationsRequest state)
   , urlForDerivation = \state ->
        url ++ show (derivationRequest state)
   }
 where
   url = "http://localhost/ideas.cgi?input="

encodeExerciseList :: [Some Exercise] -> HTMLBuilder
encodeExerciseList list = do 
   h1 "Exercises"
   forM_ (zip [1::Int ..] (grouping list)) $ \(i, (dom, xs)) -> do
      h2 (show i ++ ". " ++ dom)
      table False (map make xs)
 where
   grouping :: [Some Exercise] -> [(String, [Some Exercise])]
   grouping = map g . groupBy eq
   
   eq a b      = f a == f b
   f (Some ex) = listToMaybe (qualifiers (exerciseId ex))
   g xs        = (fromMaybe "" (f (head xs)), xs)
 
   make :: Some Exercise -> [HTMLBuilder]
   make (Some ex) = 
      [ linkToExercise lm ex $ text $ showId ex
      , text $ map toLower $ show $ status ex
      , text $ description ex
      ]

encodeExercise :: Exercise a -> HTMLBuilder
encodeExercise ex = do
   h1 $ "Exercise " ++ showId ex
   divClass "idbox" $ italic $ text (description ex)
   h2 "General information"
   generalInfo
   h2 "Example exercises"
   ul $ [ para $ linkToExamples lm ex $ text "list of examples"
        | not (null (examples ex))
        ] ++
        [ para $ do
             text "generate exercise: "
             sequence_ $ intersperse (text ", ")
                [ linkToRandomExample lm d ex $ text $ show d
                | d <- [VeryEasy .. VeryDifficult]
                ]
        | isJust (randomExercise ex)
        ] ++
        [ para $ do 
             myForm (text "other exercise: ")
             submitScript ex
        ]
   encodeRuleList ex (ruleset ex)
 where
   generalInfo = table False $ map bolds
      [ [ text "Code",   ttText (showId ex)]
      , [ text "Status", text (show $ status ex)]
      , [ text "Strategy"
        , link "" $ text (showId $ strategy ex)
        ]
      , [ text "Rules", text (show nrOfSoundRules)]
      , [ text "Buggy rules", text (show nrOfBuggyRules)]
      , [ text "OpenMath support"
        , text $ showBool $ isJust $ hasTermView ex
        ]
      {- , [ text "Textual feedback"
        , text $ showBool $ isJust $ getScript ex
        ] -}
      , [ text "Restartable strategy"
        , text $ showBool $ canBeRestarted ex
        ]
      , [ text "Exercise generator"
        , text $ showBool $ isJust $ randomExercise ex
        ]
      , [ text "Examples"
        , text $ show $ length $ examples ex
        ]
      ]
  
   (nrOfBuggyRules, nrOfSoundRules) = 
      mapBoth length (partition isBuggy (ruleset ex))
   
   bolds (x:xs) = bold x:xs
   bolds []     = []

showBool :: Bool -> String
showBool b = if b then "yes" else "no"

encodeRuleList :: Exercise a -> [Rule (Context a)] -> HTMLBuilder
encodeRuleList ex rs = do
      h1 $ "Rules for " ++ showId ex
      table True (header:map f rs2)
      h1 $ "Buggy rules for " ++ showId ex
      table True (header:map f rs1)
 where
   header = [ text "Rule name", text "Args"
            , text "Used", text "Rewrite rule"
            ]
   (rs1, rs2) = partition isBuggy rs
   used = rulesInStrategy (strategy ex)
   f r  = [ link "" $ ttText (showId r)
          , text $ show $ length $ getRefs r
          , text $ showBool $ r `elem` used
          , when (isRewriteRule r) $
               ruleToHTML (Some ex) r
          ]

htmlState :: State a -> HTMLBuilder
htmlState state = do
   h2 "state"
   text $ "state: " ++ show state
   br
   text $ " ready: " ++ show (ready state)
   br
   submitScript2 state
   myForm mempty
   parens $ linkToAllFirsts lm state $ text "allfirsts"
   parens $ linkToAllApplications lm state $ text "allapplications"
   parens $ linkToDerivation lm state $ text "derivation"

htmlDerivation :: Exercise a -> Type a t1 -> Type a t2 -> Derivation t1 t2 -> HTMLBuilder
htmlDerivation ex t1 t2 d = do 
   forTerm (firstTerm d)
   mapM_ make (triples d)
 where
   make (_, s, a) = forStep s >> forTerm a
   forTerm a = encodeType ex (a ::: t2)
   forStep s = do
      h1 "Step"
      br
      encodeType ex (s ::: t1)
      br

stateToXML :: State a -> XMLBuilder
stateToXML st = encodeState False enc st
 where
   enc = element "expr" . text . prettyPrinter (exercise st)

examplesRequest :: Exercise a -> XML
examplesRequest ex = makeXML "request" $ do
   "service"    .=. "examples"
   "exerciseid" .=. showId ex
   "encoding"   .=. "html"

generateRequest :: Difficulty -> Exercise a -> XML
generateRequest d ex = makeXML "request" $ do
   "service"    .=. "generate"
   "exerciseid" .=. showId ex
   "difficulty" .=. show d -- !!
   "encoding"   .=. "html"

allFirstsRequest :: State a -> XML
allFirstsRequest state = makeXML "request" $ do
   "service"    .=. "allfirsts"
   "exerciseid" .=. showId (exercise state)
   "encoding"   .=. "html"
   stateToXML state

allApplicationsRequest :: State a -> XML
allApplicationsRequest state = makeXML "request" $ do
   "service"    .=. "allapplications"
   "exerciseid" .=. showId (exercise state)
   "encoding"   .=. "html"
   stateToXML state

derivationRequest :: State a -> XML
derivationRequest state = makeXML "request" $ do
   "service"    .=. "derivation"
   "exerciseid" .=. showId (exercise state)
   "encoding"   .=. "html"
   stateToXML state

stateInfoRequest :: State a -> XML
stateInfoRequest state = makeXML "request" $ do
   "service"    .=. "stateinfo"
   "exerciseid" .=. showId (exercise state)
   "encoding"   .=. "html"
   stateToXML state

exerciseInfoRequest :: Exercise a -> XML
exerciseInfoRequest ex = makeXML "request" $ do
   "service"    .=. "exerciseinfo"
   "exerciseid" .=. showId ex
   "encoding"   .=. "html"

-- http://www.blooberry.com/indexdot/html/topics/urlencoding.htm
escapeInURL :: String -> String
escapeInURL = concatMap f
 where
   f '+' = "%2B"
   f '>' = "%3E"
   f '&' = "%26"
   f c   = [c]
   
parens :: HTMLBuilder -> HTMLBuilder
parens s = text " (" >> s >> text ") "


myForm :: HTMLBuilder -> HTMLBuilder
myForm this = element "form" $ do
   "name"     .=. "myform" 
   "onsubmit" .=. "return submitTerm()" 
   "method"   .=. "post"
   this
   element "input" $ do
      "type" .=. " text"
      "name" .=. "myterm"
   element "input" $ do
      "type"  .=. "submit"
      "value" .=. "Submit"

-- stateinfo service
submitScript :: Exercise a -> HTMLBuilder
submitScript ex = element "script" $ do
   "type" .=. "text/javascript"
   unescaped (getTerm ++ code)
 where
   code    = "function submitTerm() {document.myform.action = \"" ++ action ++ "\");}"
   action  = "ideas.cgi?input=\" + encodeURIComponent(\"" ++ request
   request = "<request service='stateinfo' exerciseid='" ++ showId ex 
          ++ "' encoding='html'><state><expr>\" + getTerm() + \"</expr></state></request>"

          
          
-- diagnose service
submitScript2 :: State a -> HTMLBuilder
submitScript2 st = element "script" $ do
   "type" .=. "text/javascript"
   unescaped (getTerm ++ code)
 where
   code    = "function submitTerm() {document.myform.action = \"" ++ action ++ "\");}"
   action  = "ideas.cgi?input=\" + encodeURIComponent(\"" ++ request
   request = "<request service='diagnose' exerciseid='" ++ showId (exercise st)
          ++ "' encoding='html'>" ++ ststr ++ "<expr>\"  + getTerm() + \"</expr></request>"
          
   ststr   = case fromBuilder (stateToXML st) of
                Just el -> concatMap f (show el)
                Nothing -> ""
                
   f '\\' = "\\\\"
   f c = [c]
 
getTerm :: String  
getTerm = 
   "function getTerm() {\
   \   var s = document.myform.myterm.value;\
   \   var result = \"\";\
   \   for (var i=0;i<s.length;i++) {\
   \      if (s[i]=='<') result+=\"&lt;\";\
   \      else if (s[i]=='&') result+=\"&amp;\";\
	\      else result+=s[i];\
   \   }\
   \   return result;\
   \}"