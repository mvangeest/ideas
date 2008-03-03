module Domain.Logic.Exercises where

import Domain.Logic.Zipper
import Domain.Logic.Generator
import Domain.Logic.Formula
import Domain.Logic.Strategies
import Domain.Logic.Parser
import Domain.Logic.Rules

import Common.Exercise
import Common.Strategy hiding (not)
import Common.Context
import Control.Monad

{- generator
* max. 1 equivalentie
* min. 4 stappen
* geen T/F in formule
* max. ?? stappen
-}

dnfExercise :: Exercise LogicInContext
dnfExercise = Exercise
   { shortTitle    = "Proposition to DNF" 
   , parser        = \s -> case parseLogicPars s of
                              (p, [])   -> Right (inContext p)
                              (p, msgs) -> Left  (text (show msgs), Just (inContext p))
   , prettyPrinter = ppLogicPars . noContext
   , equivalence   = \x y -> noContext x `eqLogic` noContext y
   , equality      = \x y -> noContext x == noContext y
   , finalProperty = isDNF . noContext
   , ruleset       = map liftLogicRule logicRules
   , strategy      = toDNF
   , generator     = let check p = not (isDNF p) && countEquivalences p < 2 && countBinaryOperators p <= 3
                     in liftM inContext generateLogic -- (suitableLogic check)
   , suitableTerm  = \p -> countEquivalences (noContext p) < 2 && countBinaryOperators (noContext p) <= 3
   , configuration = defaultConfiguration
   }