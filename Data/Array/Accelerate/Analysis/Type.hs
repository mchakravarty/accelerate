{-# LANGUAGE ScopedTypeVariables, GADTs, TypeFamilies, PatternGuards #-}
-- |
-- Module      : Data.Array.Accelerate.Analysis.Type
-- Copyright   : [2009..2010] Manuel M T Chakravarty, Gabriele Keller, Sean Lee
-- License     : BSD3
--
-- Maintainer  : Manuel M T Chakravarty <chak@cse.unsw.edu.au>
-- Stability   : experimental
-- Portability : non-portable (GHC extensions)
--
-- The Accelerate AST does not explicitly store much type information.  Most of
-- it is only indirectly through type class constraints -especially, 'Elem'
-- constraints- available.  This module provides functions that reify that 
-- type information in the form of a 'TupleType' value.  This is, for example,
-- needed to emit type information in a backend.

module Data.Array.Accelerate.Analysis.Type (

  -- * Query AST types
  arrayType, accType, accType2, expType, sizeOf
  
) where
  
-- standard library
import qualified Foreign.Storable as F

-- friends
import Data.Array.Accelerate.Type
import Data.Array.Accelerate.Tuple
import Data.Array.Accelerate.Array.Sugar
import Data.Array.Accelerate.AST



-- |Determine an array type
-- ------------------------

-- |Reify the element type of an array.
--
arrayType :: forall dim e. Array dim e -> TupleType (ElemRepr e)
arrayType (Array _ _) = elemType (undefined::e)


-- |Determine the type of an expressions
-- -------------------------------------

-- |Reify the element type of the result of an array computation.
--
accType :: forall aenv dim e.
           OpenAcc aenv (Array dim e) -> TupleType (ElemRepr e)
accType (Let _ acc)           = accType acc
accType (Let2 _ acc)          = accType acc
accType (Avar _)              = -- elemType (undefined::e)   -- should work - GHC 6.12 bug?
                                case arrays :: ArraysR (Array dim e) of 
                                  ArraysRarray -> elemType (undefined::e)
accType (Use arr)             = arrayType arr
accType (Unit _)              = elemType (undefined::e)
accType (Reshape _ acc)       = accType acc
accType (Replicate _ _ acc)   = accType acc
accType (Index _ acc _)       = accType acc
accType (Map _ _)             = elemType (undefined::e)
accType (ZipWith _ _ _)       = elemType (undefined::e)
accType (Fold _ _ acc)        = accType acc
accType (FoldSeg _ _ acc _)   = accType acc
accType (Fold1 _ acc)         = accType acc
accType (Fold1Seg _ acc _)    = accType acc
accType (Scanl _ _ acc)       = accType acc
accType (Scanl1 _ acc)        = accType acc
accType (Scanr _ _ acc)       = accType acc
accType (Scanr1 _ acc)        = accType acc
accType (Permute _ _ _ acc)   = accType acc
accType (Backpermute _ _ acc) = accType acc
accType (Stencil _ _ _)       = elemType (undefined::e)
accType (Stencil2 _ _ _ _ _)  = elemType (undefined::e)

-- |Reify the element types of the results of an array computation that yields
-- two arrays.
--
accType2 :: forall aenv dim1 e1 dim2 e2. OpenAcc aenv (Array dim1 e1, Array dim2 e2)
         -> (TupleType (ElemRepr e1), TupleType (ElemRepr e2))
accType2 (Let _ acc)      = accType2 acc
accType2 (Let2 _ acc)     = accType2 acc
accType2 (Avar _)         = -- (elemType (undefined::e1), elemType (undefined::e2))
                            -- should work - GHC 6.12 bug?
                            case arrays :: ArraysR (Array dim1 e1, Array dim2 e2) of 
                              ArraysRpair ArraysRarray ArraysRarray 
                                -> (elemType (undefined::e1), elemType (undefined::e2))
                              _ -> error "GHC is too dumb to realise that this is dead code"
accType2 (Scanl' _ e acc) = (accType acc, expType e)
accType2 (Scanr' _ e acc) = (accType acc, expType e)

-- |Reify the result type of a scalar expression.
--
expType :: forall aenv env t. OpenExp aenv env t -> TupleType (ElemRepr t)
expType (Var _)             = elemType (undefined::t)
expType (Const _)           = elemType (undefined::t)
expType (Tuple _)           = elemType (undefined::t)
expType (Prj idx _)         = tupleIdxType idx
expType IndexNil            = elemType (undefined::t)
expType (IndexCons _ _)     = elemType (undefined::t)
expType (IndexHead _)       = elemType (undefined::t)
expType (IndexTail _)       = elemType (undefined::t)
expType (Cond _ t _)        = expType t
expType (PrimConst _)       = elemType (undefined::t)
expType (PrimApp _ _)       = elemType (undefined::t)
expType (IndexScalar acc _) = accType acc
expType (Shape _)           = elemType (undefined::t)
expType (Size _)            = elemType (undefined::t)

-- |Reify the result type of a tuple projection.
--
tupleIdxType :: forall t e. TupleIdx t e -> TupleType (ElemRepr e)
tupleIdxType ZeroTupIdx       = elemType (undefined::e)
tupleIdxType (SuccTupIdx idx) = tupleIdxType idx


-- |Size of a tuple type, in bytes
--
sizeOf :: TupleType a -> Int
sizeOf UnitTuple       = 0
sizeOf (PairTuple a b) = sizeOf a + sizeOf b

sizeOf (SingleTuple (NumScalarType (IntegralNumType t)))
  | IntegralDict <- integralDict t = F.sizeOf $ (undefined :: IntegralType a -> a) t
sizeOf (SingleTuple (NumScalarType (FloatingNumType t)))
  | FloatingDict <- floatingDict t = F.sizeOf $ (undefined :: FloatingType a -> a) t
sizeOf (SingleTuple (NonNumScalarType t))
  | NonNumDict   <- nonNumDict t   = F.sizeOf $ (undefined :: NonNumType a   -> a) t

