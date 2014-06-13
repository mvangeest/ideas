-----------------------------------------------------------------------------
-- Copyright 2014, Open Universiteit Nederland. This file is distributed
-- under the terms of the GNU General Public License. For more information,
-- see the file "LICENSE.txt", which is included in the distribution.
-----------------------------------------------------------------------------
-- |
-- Maintainer  :  bastiaan.heeren@ou.nl
-- Stability   :  provisional
-- Portability :  portable (depends on ghc)
--
-- A type class for sequences together with the 'Step' datatype. 
-- 
-----------------------------------------------------------------------------
--  $Id: Sequential.hs 6612 2014-06-12 07:57:59Z bastiaan $

module Ideas.Common.Strategy.Sequence 
   ( -- * Sequence type class
     Sequence(..)
     -- * Step data type with some utility functions
   , Step(..), step, isDone
   ) where

infixr 5 :~>, ~>, <*>

------------------------------------------------------------------------
-- Sequence type class

class Sequence f where
   -- | The empty sequence.
   done :: f a
   -- | Prefix a sequence with one element. 
   (~>) :: a -> f a -> f a
   -- | Append two sequences.
   (<*>) :: f a -> f a -> f a

------------------------------------------------------------------------
-- Step data type with some utility functions
  
data Step f a = a :~> f a   -- ^ A single step.
              | Done        -- ^ No step (we are done).

instance Sequence f => Sequence (Step f) where
   done   = Done
   a ~> x = a :~> fromStep x

   Done      <*> y = y
   (a :~> x) <*> y = a :~> (x <*> fromStep y)

instance Functor f => Functor (Step f) where
   fmap _ Done      = Done
   fmap f (a :~> x) = f a :~> fmap f x

-- | The 'step' function takes a default value for 'Done' and a function 
-- to combine the values for a single step.
step :: b -> (a -> f a -> b) -> Step f a -> b
step b _ Done      = b
step _ f (a :~> x) = f a x

-- | Is the step 'done'?
isDone :: Step f a -> Bool
isDone Done = True
isDone _    = False

-- local helper
fromStep :: Sequence f => Step f a -> f a
fromStep = step done (~>)