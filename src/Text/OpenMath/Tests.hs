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
module Text.OpenMath.Tests (propEncoding) where

import Control.Monad
import Text.OpenMath.Object
import Test.QuickCheck
import Text.OpenMath.Dictionary.Arith1
import Text.OpenMath.Dictionary.Calculus1
import Text.OpenMath.Dictionary.Fns1
import Text.OpenMath.Dictionary.Linalg2
import Text.OpenMath.Dictionary.List1
import Text.OpenMath.Dictionary.Logic1
import Text.OpenMath.Dictionary.Nums1
import Text.OpenMath.Dictionary.Quant1
import Text.OpenMath.Dictionary.Relation1
import Text.OpenMath.Dictionary.Transc1

arbOMOBJ :: Gen OMOBJ
arbOMOBJ = sized rec 
 where
   symbols = arith1List ++ calculus1List ++ fns1List ++ linalg2List ++
      list1List ++ logic1List ++ nums1List ++ quant1List ++ 
      relation1List ++ transc1List
 
   rec 0 = frequency 
      [ (1, liftM OMI arbitrary)
      , (1, liftM OMF arbitrary)
      , (1, liftM OMV arbitrary)
      , (5, oneof $ map (return . OMS) symbols)
      ]
   rec n = frequency
      [ (1, rec 0)
      , (3, choose (1,4) >>= liftM OMA . (`replicateM` f))
      , (1, liftM3 OMBIND f arbitrary f)
      ]
    where
      f = rec (n `div` 2)

propEncoding :: Property
propEncoding = forAll arbOMOBJ $ \x -> xml2omobj (omobj2xml x) == Right x