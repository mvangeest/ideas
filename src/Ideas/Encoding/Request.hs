-----------------------------------------------------------------------------
-- Copyright 2016, Ideas project team. This file is distributed under the
-- terms of the Apache License 2.0. For more information, see the files
-- "LICENSE.txt" and "NOTICE.txt", which are included in the distribution.
-----------------------------------------------------------------------------
-- |
-- Maintainer  :  bastiaan.heeren@ou.nl
-- Stability   :  provisional
-- Portability :  portable (depends on ghc)
--
-----------------------------------------------------------------------------

module Ideas.Encoding.Request where

import Control.Applicative
import Data.Char
import Data.List
import Data.Maybe
import Ideas.Common.Library hiding (exerciseId)
import Ideas.Utils.Prelude

data Request = Request
   { serviceId      :: Maybe Id
   , exerciseId     :: Maybe Id
   , source         :: Maybe String
   , feedbackScript :: Maybe String
   , requestInfo    :: Maybe String
   , cgiBinary      :: Maybe String
   , logSchema      :: Maybe Schema
   , randomSeed     :: Maybe Int
   , dataformat     :: Maybe DataFormat -- default: XML
   , encoding       :: [Encoding]
   }

instance Monoid Request where
   mempty = Request Nothing Nothing Nothing Nothing
                    Nothing Nothing Nothing Nothing Nothing []
   mappend x y = Request
      { serviceId      = make serviceId
      , exerciseId     = make exerciseId
      , source         = make source
      , feedbackScript = make feedbackScript
      , requestInfo    = make requestInfo
      , cgiBinary      = make cgiBinary
      , logSchema      = make logSchema
      , randomSeed     = make randomSeed
      , dataformat     = make dataformat
      , encoding       = encoding x <> encoding y
      }
    where
      make f = f x <|> f y

data Schema = V1 | V2 | NoLogging deriving (Show, Eq)

getSchema :: Request -> Schema
getSchema = fromMaybe V1 . logSchema -- log schema V1 is the default

readSchema :: Monad m => String -> m Schema
readSchema s0
   | s == "v1" = return V1
   | s == "v2" = return V2
   | s `elem` ["false", "no"] = return NoLogging
   | otherwise = fail "Unknown schema"
 where
   s = map toLower (filter isAlphaNum s0)

data DataFormat = XML | JSON
   deriving Show -- needed for LoggingDatabase

data Encoding = EncHTML      -- html page as output
              | EncOpenMath  -- encode terms in OpenMath
              | EncString    -- encode terms as strings
              | EncCompact   -- compact ouput
              | EncPretty    -- pretty output
              | EncJSON      -- encode terms in JSON
 deriving Eq

instance Show Encoding where
   showList xs rest = intercalate "+" (map show xs) ++ rest
   show EncHTML     = "html"
   show EncOpenMath = "openmath"
   show EncString   = "string"
   show EncCompact  = "compact"
   show EncPretty   = "pretty"
   show EncJSON     = "json"

htmlOutput :: Request -> Bool
htmlOutput = (EncHTML `elem`) . encoding

compactOutput :: Request -> Bool
compactOutput req =
   case (EncCompact `elem` xs, EncPretty `elem` xs) of
      (True, False) -> True
      (False, True) -> False
      _             -> isJust (cgiBinary req)
 where
   xs = encoding req

useOpenMath :: Request -> Bool
useOpenMath r =
   case dataformat r of
      Just JSON -> False
      _ -> all (`notElem` encoding r) [EncString, EncHTML]

useJSONTerm :: Request -> Bool
useJSONTerm r =
   case dataformat r of
      Just JSON -> EncJSON `elem` encoding r
      _ -> False

useLogging :: Request -> Bool
useLogging = (EncHTML `notElem`) . encoding

discoverDataFormat :: Monad m => String -> m DataFormat
discoverDataFormat xs =
   case dropWhile isSpace xs of
      '<':_ -> return XML
      '{':_ -> return JSON
      _     -> fail "Unknown data format"

readEncoding :: Monad m => String -> m [Encoding]
readEncoding = mapM (f . map toLower) . splitsWithElem '+'
 where
   f "html"     = return EncHTML
   f "openmath" = return EncOpenMath
   f "string"   = return EncString
   f "compact"  = return EncCompact
   f "pretty"   = return EncPretty
   f "json"     = return EncJSON
   f s          = fail $ "Invalid encoding: " ++ s