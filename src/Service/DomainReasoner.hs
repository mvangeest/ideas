{-# OPTIONS -XMultiParamTypeClasses -XTypeSynonymInstances #-}
-----------------------------------------------------------------------------
-- Copyright 2010, Open Universiteit Nederland. This file is distributed 
-- under the terms of the GNU General Public License. For more information, 
-- see the file "LICENSE.txt", which is included in the distribution.
-----------------------------------------------------------------------------
-- |
-- Maintainer  :  bastiaan.heeren@ou.nl
-- Stability   :  provisional
-- Portability :  portable (depends on ghc)
--
-----------------------------------------------------------------------------
module Service.DomainReasoner 
   ( -- * Domain Reasoner data type
     DomainReasoner, runDomainReasoner, runWithCurrent
   , liftEither, MonadIO(..), catchError 
     -- * Update functions
   , addPackages, addPackage, addPkgService
   , addServices, addService, addTestSuite
   , setVersion, setFullVersion
     -- * Accessor functions
   , getPackages, getExercises, getServices
   , getVersion, getFullVersion, getTestSuite
   , findPackage, findService
   ) where

import Common.Exercise
import Common.TestSuite
import Common.Utils (Some(..))
import Control.Monad.Error
import Control.Monad.State
import Service.Types
import Service.ExercisePackage

-----------------------------------------------------------------------
-- Domain Reasoner data type

newtype DomainReasoner a = DR { unDR :: ErrorT String (StateT Content IO) a }

data Content = Content
   { packages    :: [Some ExercisePackage]
   , services    :: [Some ExercisePackage] -> [Service]
   , testSuite   :: TestSuite
   , version     :: String
   , fullVersion :: Maybe String
   }
   
noContent :: Content
noContent = Content [] (const []) (return ()) [] Nothing

runDomainReasoner :: DomainReasoner a -> IO a
runDomainReasoner m = do
   result <- evalStateT (runErrorT (unDR m)) noContent
   case result of
      Left msg -> fail msg
      Right a  -> return a

-- | Returns a run function, based on the current state, inside the monad
runWithCurrent :: DomainReasoner (DomainReasoner a -> IO a)
runWithCurrent =
   get >>= \st -> return (runDomainReasoner . (put st >>))

liftEither :: Either String a -> DomainReasoner a
liftEither = either fail return

-----------------------------------------------------------------------
-- Instance declarations

instance Monad DomainReasoner where
   return a   = DR (return a)
   DR m >>= f = DR (m >>= unDR . f)
   fail s     = DR (fail s)

instance MonadError String DomainReasoner where
   throwError     = fail
   catchError m f = DR (unDR m `catchError` (unDR . f))

instance MonadPlus DomainReasoner where
   mzero       = DR mzero
   a `mplus` b = DR (unDR a `mplus` unDR b)

instance MonadState Content DomainReasoner where
   get   = DR get
   put s = DR (put s)

instance MonadIO DomainReasoner where
   liftIO m = DR (liftIO m)

-----------------------------------------------------------------------
-- Update functions

addPackages :: [Some ExercisePackage] -> DomainReasoner ()
addPackages xs = modify $ \c -> c { packages = xs ++ packages c }

addPackage :: Some ExercisePackage -> DomainReasoner ()
addPackage pkg = addPackages [pkg]

addPkgService :: ([Some ExercisePackage] -> Service) -> DomainReasoner ()
addPkgService f = modify $ \c -> 
   c { services = \xs -> f xs : services c xs }

addServices :: [Service] -> DomainReasoner ()
addServices = mapM_ addPkgService . map const

addService :: Service -> DomainReasoner ()
addService s = addServices [s]

addTestSuite :: TestSuite -> DomainReasoner ()
addTestSuite m = modify $ \c -> c { testSuite = testSuite c >> m }

setVersion :: String -> DomainReasoner ()
setVersion s = modify $ \c -> c { version = s }

setFullVersion :: String -> DomainReasoner ()
setFullVersion s = modify $ \c -> c  { fullVersion = Just s }

-----------------------------------------------------------------------
-- Accessor functions

getPackages :: DomainReasoner [Some ExercisePackage]
getPackages = gets packages

getExercises :: DomainReasoner [Some Exercise]
getExercises = gets (map (\(Some pkg) -> Some (exercise pkg)) . packages)

getServices :: DomainReasoner [Service]
getServices = gets (\c -> services c (packages c))

getVersion :: DomainReasoner String
getVersion = gets version

getFullVersion :: DomainReasoner String
getFullVersion = gets fullVersion >>= maybe getVersion return

getTestSuite :: DomainReasoner TestSuite
getTestSuite = gets testSuite

findPackage :: ExerciseCode -> DomainReasoner (Some ExercisePackage)
findPackage code = do
   pkgs <- getPackages 
   let p (Some pkg) = exerciseCode (exercise pkg) == code
   case filter p pkgs of
      [this] -> return this
      _      -> fail $ "Package " ++ show code ++ " not found"
      
findService :: String -> DomainReasoner Service
findService txt = do
   srvs <- getServices
   case filter ((==txt) . serviceName) srvs of
      [hd] -> return hd
      []   -> fail $ "No service " ++ txt
      _    -> fail $ "Ambiguous service " ++ txt