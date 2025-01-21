mod types;
mod test;
use dep::aztec::macros::aztec;

#[aztec]
contract UIntBenchmark {
    use dep::aztec::macros::{functions::{initializer, internal, private, public}, storage::storage};
    use dep::aztec::prelude::{AztecAddress, PrivateMutable, PublicMutable};

    use crate::types::u64note::U64Note;
    use uint253::uint253_note::{U253, U253Note};
    use uint_note::uint_note::UintNote;

    // use bignum::{BigNum, BigNumTrait};
    // type U256 = BigNum<3, 257, bignum::fields::U256::U256Params>;

    #[storage]
    struct Storage<Context> {
        u64_private: PrivateMutable<U64Note, Context>,
        u128_private: PrivateMutable<UintNote, Context>,
        u253_private: PrivateMutable<U253Note, Context>,
        // u256_private: PrivateMutable<U256, Context>,

        u64_public: PublicMutable<u64, Context>,
        u128_public: PublicMutable<U128, Context>,
        u253_public: PublicMutable<U253, Context>,
    }

    #[public]
    #[initializer]
    // annotation to mark function as a constructor
    fn constructor() {
        storage.u64_public.write(0 as u64);
        storage.u128_public.write(U128::from_integer(0));
        storage.u253_public.write(U253::new(0));
    }

    #[private]
    fn priv_fn_64(number: Field) {
        let owner = AztecAddress::zero();
        let mut new_note = U64Note::new(number as u64, owner);
        storage.u64_private.initialize_or_replace(&mut new_note);
        UIntBenchmark::at(context.this_address()).pub_fn_64(number as u64).enqueue(&mut context);
    }

    #[private]
    fn priv_fn_128(number: Field) {
        let owner = AztecAddress::zero();
        let mut new_note = UintNote::new(U128::from_integer(number), owner);
        storage.u128_private.initialize_or_replace(&mut new_note);
        UIntBenchmark::at(context.this_address()).pub_fn_128(U128::from_integer(number)).enqueue(
            &mut context,
        );
    }

    #[private]
    fn priv_fn_253(number: Field) {
        let owner = AztecAddress::zero();
        let mut new_note = U253Note::new(U253::from_integer(number), owner);
        storage.u253_private.initialize_or_replace(&mut new_note);
        UIntBenchmark::at(context.this_address()).pub_fn_253(U253::from_integer(number)).enqueue(
            &mut context,
        );
    }

    #[internal]
    #[public]
    fn pub_fn_64(number: u64) {
        storage.u64_public.write(number);
    }

    #[internal]
    #[public]
    fn pub_fn_128(number: U128) {
        storage.u128_public.write(number);
    }

    #[internal]
    #[public]
    fn pub_fn_253(number: U253) {
        storage.u253_public.write(number);
    }

}
