{-# LANGUAGE GADTs, Rank2Types #-}
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
-----------------------------------------------------------------------------
module Ideas.Service.Evaluator 
   ( EncoderState, simpleEncoder, maybeEncoder, eitherEncoder
   , failArrow, encoderError, encoderFor, encoderStateFor, encodeTyped
   , runEncoderState, runEncoderStateM, (//)
   , choice
     -- re-export
   , pure, (<$>)
     -- old
   , encodeWith, Evaluator(..), evalService
   ) where

import qualified Control.Category as C
import Ideas.Common.Classes
import Data.List
import Ideas.Common.View
import Control.Arrow
import Control.Applicative hiding (Const)
import Data.Monoid
import Ideas.Service.Types

newtype EncoderState st a b = Enc (st -> a -> Either [String] b)

instance C.Category (EncoderState st) where
   id = Enc $ \_ -> Right
   Enc f . Enc g = Enc $ \st -> either Left (f st) . g st

instance Arrow (EncoderState st) where
   arr f = Enc $ \_ -> Right . f
   first (Enc f) = Enc $ \st (a, c) -> fmap (\b -> (b, c)) (f st a)

instance ArrowZero (EncoderState st) where
   zeroArrow = Enc $ \_ _ -> Left []

instance ArrowPlus (EncoderState st) where
   Enc f <+> Enc g = Enc $ \st a -> 
      case (f st a, g st a) of
         (Right b, _      ) -> Right b
         (_,       Right b) -> Right b
         (Left e1, Left e2) -> Left (e1 ++ e2)

instance ArrowChoice (EncoderState st) where
   left (Enc f) = Enc $ \st -> either (fmap Left . f st) (Right . Right)

instance ArrowApply (EncoderState st) where
   app = Enc $ \st (Enc f, a) -> f st a

instance Functor (EncoderState st a) where
   fmap = liftA

instance Applicative (EncoderState st a) where
   pure    = arr . const
   f <*> g = f &&& g >>> arr (uncurry ($))
   
instance Monoid b => Monoid (EncoderState st a b) where
   mempty  = pure mempty
   mappend = liftA2 (<>)

failArrow :: EncoderState st String a
failArrow = Enc $ \_ err -> Left [ err | not (null err) ]

stateArrow :: EncoderState st a (st, a)
stateArrow = Enc $ \st a -> Right (st, a)

runEncoderState :: EncoderState st a b -> st -> a -> Either String b
runEncoderState (Enc f) st = mapFirst (concat . intersperse ", ") . f st

---

simpleEncoder :: (a -> b) -> EncoderState st a b
simpleEncoder = arr

maybeEncoder :: (a -> Maybe b) -> EncoderState st a b
maybeEncoder f = eitherEncoder (maybe (Left []) Right . f)

eitherEncoder :: (a -> Either String b) -> EncoderState st a b
eitherEncoder f = arr f >>> failArrow ||| C.id

encoderError :: String -> EncoderState st a b
encoderError err = arr (const err) >>> failArrow

encoderFor :: (a -> EncoderState st a b) -> EncoderState st a b
encoderFor = encoderStateFor . const

encoderStateFor :: (st -> a -> EncoderState st a b) -> EncoderState st a b
encoderStateFor f = (stateArrow >>> arr (uncurry f)) &&& C.id >>> app
      
runEncoderStateM :: Monad m => EncoderState st a b -> st -> a -> m b
runEncoderStateM f st = either fail return . runEncoderState f st

encodeTyped :: Typed a t => EncoderState st t b -> EncoderState st (TypedValue (Type a)) b
encodeTyped enc = fromTyped >>> enc

infixl 8 //

(//) :: EncoderState st a c -> a -> EncoderState st b c
f // a = arr (const a) >>> f


----

choice :: ArrowPlus f => [f a b] -> f a b
choice = foldr (<+>) zeroArrow

fromTyped :: Typed a t => EncoderState st (TypedValue (Type a)) t
fromTyped = maybeEncoder $ \(val ::: tp) -> fmap ($ val) (equal tp typed)

-------------------------------------------------------------------

evalService :: Monad m => Evaluator (Const b) m a -> Service -> m a
evalService f = eval f . serviceFunction

data Evaluator f m a = Evaluator
   { encoder :: TypedValue (TypeRep f) -> m a
   , decoder :: forall t . TypeRep f t -> m t
   }

{-
type Fix a = a -> a

encodeTypeRep :: Monoid a => (TypedValue f -> a) -> TypedValue (TypeRep f) -> a
encodeTypeRep = fix . encodeTypeRepFix

encodeTypeRepFix :: Monoid a => (TypedValue f -> a) -> Fix (TypedValue (TypeRep f) -> a)
encodeTypeRepFix enc rec (val ::: tp) = 
   case tp of
      _ :-> _    -> mempty
      t1 :|: t2  -> case val of
                       Left a  -> rec (a ::: t1)
                       Right a -> rec (a ::: t2)
      Pair t1 t2 -> rec (fst val ::: t1) <> rec (snd val ::: t2)
      List t     -> mconcat (map (rec . (::: t)) val)  
      Tree t     -> F.fold (fmap (rec . (::: t)) val)
      Unit       -> mempty
      Tag _ t    -> rec (val ::: t)
      Iso v t    -> rec (to v val ::: t)
      Const ctp  -> enc (val ::: ctp) -}
      
encodeWith :: (Monad m, Typed a t) => (t -> m b) -> TypedValue (Type a) -> m b
encodeWith enc (val ::: tp) =
   case equal tp typed of 
      Just f  -> enc (f val)
      Nothing -> fail "encoding failed"

eval :: Monad m => Evaluator f m a -> TypedValue (TypeRep f) -> m a
eval f tv@(val ::: tp) =
   case tp of
      t1 :-> t2 -> do
         a <- decoder f t1
         eval f (val a ::: t2)
      _ ->
         encoder f tv