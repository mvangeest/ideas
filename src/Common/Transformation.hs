{-# LANGUAGE ExistentialQuantification #-}
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
-- This module defines transformations. Given a term, a transformation returns 
-- a list of results (often a singleton list or the empty list). A 
-- transformation can be parameterized with one or more Bindables. 
-- Transformations rules can be lifted to work on more complex domains with
-- the LiftView type class.
--
-----------------------------------------------------------------------------
module Common.Transformation
   ( -- * Transformations
     Transformation, HasTransformation(..)
   , makeTrans, makeTransG
     -- * Bindables
   , ParamTrans, supplyParameters
     -- * Recognizers
   , transRecognizer
     -- * Extract information
   , getRewriteRules
     -- * QuickCheck generator
   , smartGen
     -- * Recognizer
   , Recognizer, makeRecognizer, makeListRecognizer, simpleRecognizer
   , recognize, recognizeList, buggyRecognizer, isBuggyRecognizer
   ) where

import Common.Algebra.Field
import Common.Binding
import Common.Classes
import Common.Id
import Common.Parameterized
import Common.Results
import Common.Rewriting
import Common.Utils
import Common.View
import Control.Monad
import Data.Maybe
import Test.QuickCheck

-----------------------------------------------------------
--- Transformations

-- | Abstract data type for representing transformations
data Transformation a
   = Function (a -> Results a)
   | RewriteRule (RewriteRule a) (a -> Results a)
   | forall b c . LiftView (View a (b, c)) (Transformation b)
   | Transformation a :*: Transformation a
   | Transformation a :|: Transformation a

instance SemiRing (Transformation a) where
   zero  = makeTrans (const Nothing)
   (<+>) = (:|:)
   one   = makeTrans Just
   (<*>) = (:*:)

instance Apply Transformation where
   applyAll t = fromResults . applyResults t

instance ApplyResults Transformation where
   applyResults trans a =
      case trans of
         Function f      -> f a
         RewriteRule _ f -> f a
         LiftView v t    -> do (b0, c) <- matchM v a
                               b <- applyResults t b0
                               return (build v (b, c))
         t1 :|: t2       -> applyResults t1 a `mplus` applyResults t2 a
         t1 :*: t2       -> applyResults t1 a >>= applyResults t2

instance LiftView Transformation where
   liftViewIn = LiftView

-- | Turn a function (which returns its result in the Maybe monad) into a transformation
makeTrans :: (a -> Maybe a) -> Transformation a
makeTrans = makeTransG

-- | Turn a function (which returns a list of results) into a transformation
makeTransG :: ToResults f => (a -> f a) -> Transformation a
makeTransG f = Function (toResults . f)

-----------------------------------------------------------
--- HasTransformation type class

class HasTransformation f where
   transformation :: f a -> Transformation a

instance HasTransformation Transformation where
   transformation = id

instance HasTransformation RewriteRule where
   -- no matching information is used
   transformation r = RewriteRule r (toResults . applyAll r)

-----------------------------------------------------------
--- Bindables

type ParamTrans p a = Parameterized p (Transformation a)

supplyParameters :: Parameterized p (Transformation a) -> (a -> Results p) -> Transformation a
supplyParameters r f = makeTransG $ \a -> do
   p <- f a
   let (trans, extra) = unParam r p
   addLocalEnvironment extra
   applyResults trans a

-----------------------------------------------------------
--- Rules

getRewriteRules :: HasTransformation f => f a -> [Some RewriteRule]
getRewriteRules = rec . transformation 
 where
   rec :: Transformation a -> [Some RewriteRule]
   rec trans =
      case trans of
         Function _        -> []
         RewriteRule rr _  -> [Some rr]
         LiftView _ t      -> rec t
         t1 :|: t2         -> rec t1 ++ rec t2
         t1 :*: t2         -> rec t1 ++ rec t2

transRecognizer :: (IsId n, HasTransformation f)
                => (a -> a -> Bool) -> n -> f a -> Recognizer a
transRecognizer eq n f = makeListRecognizer n $ \a b -> 
   fromResults $ do
      x <- applyResults (transformation f) a
      guard (x `eq` b)
      getLocals

-----------------------------------------------------------
--- QuickCheck

smartGen :: HasTransformation f => f a -> a -> Maybe (Gen a)
smartGen = flip rec . transformation
 where
   rec :: a -> Transformation a -> Maybe (Gen a)
   rec a trans = 
      case trans of
         RewriteRule r _ -> return (smartGenerator r)
         LiftView v t -> do
            (b, c) <- matchM v a
            gen    <- rec b t
            return $ liftM (\n -> build v (n, c)) gen
         t1 :|: t2 -> recs [t1, t2]
         t1 :*: t2 -> recs [t1, t2]
         _ -> Nothing
    where
      recs ts =
         case mapMaybe (rec a) ts of
            [] -> Nothing
            xs -> return (oneof xs)
            
-----------------------------------------------------------
--- Recognizer

data Recognizer a = Recognizer 
   { recognizerId      :: Id
   , recognizeList     :: a -> a -> [Environment]
   , isBuggyRecognizer :: Bool
   }

instance HasId (Recognizer a) where
   getId = recognizerId 
   changeId f r = r {recognizerId = f (recognizerId r)}

instance LiftView Recognizer where
   liftViewIn v r = r {recognizeList = make}
    where
      make a b = do
         (x, _) <- matchM v a
         (y, _) <- matchM v b
         recognizeList r x y

makeRecognizer :: IsId n => n -> (a -> a -> Maybe Environment) -> Recognizer a
makeRecognizer n f = makeListRecognizer n (\a b -> maybeToList $ f a b)

makeListRecognizer :: IsId n => n -> (a -> a -> [Environment]) -> Recognizer a
makeListRecognizer n f = Recognizer (newId n) f False

simpleRecognizer :: IsId n => n -> (a -> a -> Bool) -> Recognizer a
simpleRecognizer n eq = makeRecognizer n $ \a b ->
   guard (eq a b) >> return mempty

recognize :: Recognizer a -> a -> a -> Maybe Environment
recognize r a b = listToMaybe $ recognizeList r a b 

buggyRecognizer :: Recognizer a -> Recognizer a
buggyRecognizer r = r {isBuggyRecognizer = True}