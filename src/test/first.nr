use crate::test::utils;
use dep::authwit::cheatcodes as authwit_cheatcodes;
use dep::aztec::oracle::{execution::get_block_number, storage::storage_read};
use dep::aztec::prelude::{AztecAddress, NoteHeader};
use dep::aztec::protocol_types::storage::map::derive_storage_slot_in_map;
use dep::token::Token;
use dep::uint_note::uint_note::UintNote;

use std::test::OracleMock;

use crate::EasyPrivateVoting;

#[test]
unconstrained fn test_initializer() {
    let (_, voting_contract_address, token_contract_address, admin) = utils::setup();

    let block_number = get_block_number();
    let admin_slot = EasyPrivateVoting::storage_layout().admin.slot;
    let admin_storage_value = storage_read(voting_contract_address, admin_slot, block_number);
    assert(admin_storage_value == admin, "Vote ended should be false");

    let token_slot = EasyPrivateVoting::storage_layout().token_address.slot;
    let token_storage_value = storage_read(voting_contract_address, token_slot, block_number);
    assert(token_storage_value == token_contract_address, "Token address should be set");
}

// #[test]
// unconstrained fn test_check_vote_status() {
//     let (_, voting_contract_address, _, _) = utils::setup();

//     let vote_ended_expected: bool = false;

//     let block_number = get_block_number();
//     let status_slot = EasyPrivateVoting::storage_layout().vote_ended.slot;
//     let vote_ended_read: bool = storage_read(voting_contract_address, status_slot, block_number);
//     assert(vote_ended_expected == vote_ended_read, "Vote ended should be false");
// }

// #[test]
// unconstrained fn test_end_vote() {
//     let (env, voting_contract_address, _, admin) = utils::setup();

//     env.impersonate(admin);
//     EasyPrivateVoting::at(voting_contract_address).end_vote().call(&mut env.public());

//     let vote_ended_expected = true;

//     let block_number = get_block_number();
//     let status_slot = EasyPrivateVoting::storage_layout().vote_ended.slot;
//     let vote_ended_read: bool = storage_read(voting_contract_address, status_slot, block_number);
//     assert(vote_ended_expected == vote_ended_read, "Vote ended should be true");
// }

// #[test(should_fail)]
// unconstrained fn test_fail_end_vote_by_non_admin() {
//     let (env, voting_contract_address, _) = utils::setup();
//     let alice = env.create_account();

//     env.impersonate(alice);
//     EasyPrivateVoting::at(voting_contract_address).end_vote().call(&mut env.public());
// }

// NOTE: failing with "Balance too low" error
#[test]
unconstrained fn test_cast_vote() {
    let (env, voting_contract_address, token_contract_address, admin) = utils::setup();
    let alice = env.create_account_contract(1);

    let note_randomness = 420;
    let _ = OracleMock::mock("getRandomField").returns(note_randomness);
    let balances_owner_slot =
        derive_storage_slot_in_map(Token::storage_layout().balances.slot, alice);

    env.impersonate(admin);
    Token::at(token_contract_address).mint_to_private(alice, alice, U128::from_integer(101)).call(
        &mut env.private(),
    );
    env.advance_block_by(1);

    env.add_note(
        &mut UintNote {
            value: U128::from_integer(101),
            owner: alice,
            randomness: note_randomness,
            header: NoteHeader::empty(),
        },
        balances_owner_slot,
        token_contract_address,
    );
    env.advance_block_by(1);

    prepare_authwit(
        token_contract_address,
        voting_contract_address,
        alice,
        100,
        0,
    );

    // NOTE: failing (see #8771)
    // check_private_balance(token_contract_address, alice, 100);
    let candidate = 1;
    env.advance_block_by(6);
    env.impersonate(alice);
    EasyPrivateVoting::at(voting_contract_address).cast_vote(candidate).call(&mut env.private());

    // Read vote count from storage
    let block_number = get_block_number();
    let tally_slot = EasyPrivateVoting::storage_layout().tally.slot;
    let candidate_tally_slot = derive_storage_slot_in_map(tally_slot, candidate);
    let vote_count: u32 = storage_read(voting_contract_address, candidate_tally_slot, block_number);

    assert(vote_count == 100, "vote tally should be incremented");
}

// #[test(should_fail)]
// unconstrained fn test_fail_cast_vote_with_low_balance() {
//     let (env, voting_contract_address, token_contract_address, admin) = utils::setup();
//     let alice = env.create_account();

//     env.impersonate(admin);
//     Token::at(token_contract_address).mint_to_private( admin, alice, 99).call(&mut env.private());

//     env.impersonate(alice);

//     let candidate = 1;
//     env.advance_block_by(6);
//     // NOTE: cast_vote assumes Alice has 100 tokens, but she has 99
//     EasyPrivateVoting::at(voting_contract_address).cast_vote(candidate).call(&mut env.private());
// }

// #[test]
// unconstrained fn test_cast_vote_with_separate_accounts() {
//     let (env, voting_contract_address, token_contract_address, admin) = utils::setup();
//     let alice = env.create_account();
//     let bob = env.create_account();

//     let candidate = 101;

//     env.impersonate(admin);
//     Token::at(token_contract_address).mint_to_private( admin, alice, 100).call(&mut env.private());
//     Token::at(token_contract_address).mint_to_private( admin, bob, 100).call(&mut env.private());

//     env.impersonate(alice);
//     env.advance_block_by(1);
//     EasyPrivateVoting::at(voting_contract_address).cast_vote(candidate).call(&mut env.private());

//     env.impersonate(bob);
//     env.advance_block_by(1);
//     EasyPrivateVoting::at(voting_contract_address).cast_vote(candidate).call(&mut env.private());

//     // Read vote count from storage
//     let block_number = get_block_number();
//     let tally_slot = EasyPrivateVoting::storage_layout().tally.slot;
//     let candidate_tally_slot = derive_storage_slot_in_map(tally_slot, candidate);
//     let vote_count: u32 = storage_read(voting_contract_address, candidate_tally_slot, block_number);

//     assert(vote_count == 200, "vote tally should be 200");
// }

// #[test]
// unconstrained fn test_cast_vote_with_delegation() {
//     let (env, voting_contract_address, token_contract_address, admin) = utils::setup();
//     let alice = env.create_account();
//     let bob = env.create_account();

//     let candidate = 101;
//     let random = 420;

//     env.impersonate(admin);
//     Token::at(token_contract_address).mint_to_private( admin, alice, 100).call(&mut env.private());
//     Token::at(token_contract_address).mint_to_private( admin, bob, 100).call(&mut env.private());

//     env.impersonate(alice);
//     env.advance_block_by(1);
//     EasyPrivateVoting::at(voting_contract_address).delegate_vote(bob, random).call(&mut env.private());

//     env.impersonate(bob);
//     env.advance_block_by(1);
//     EasyPrivateVoting::at(voting_contract_address).cast_delegated_vote(candidate).call(&mut env.private());

//     // Read vote count from storage
//     let block_number = get_block_number();
//     let tally_slot = EasyPrivateVoting::storage_layout().tally.slot;
//     let candidate_tally_slot = derive_storage_slot_in_map(tally_slot, candidate);
//     let vote_count: u32 = storage_read(voting_contract_address, candidate_tally_slot, block_number);

//     assert(vote_count == 100, "vote tally should be 100");
// }

// #[test]
// unconstrained fn test_cast_vote_with_multiple_delegations() {
//     let (env, voting_contract_address, token_contract_address, admin) = utils::setup();
//     let alice = env.create_account();
//     let bob = env.create_account();
//     let carl = env.create_account();
//     let dave = env.create_account();
//     let delegatee = env.create_account();

//     let candidate = 101;
//     let random = 420;

//     env.impersonate(admin);
//     Token::at(token_contract_address).mint_to_private( admin, alice, 100).call(&mut env.private());
//     Token::at(token_contract_address).mint_to_private( admin, bob, 100).call(&mut env.private());
//     Token::at(token_contract_address).mint_to_private( admin, carl, 100).call(&mut env.private());
//     Token::at(token_contract_address).mint_to_private( admin, dave, 100).call(&mut env.private());

//     env.impersonate(alice);
//     env.advance_block_by(1);
//     EasyPrivateVoting::at(voting_contract_address).delegate_vote(delegatee, random).call(&mut env.private());

//     env.impersonate(bob);
//     env.advance_block_by(1);
//     EasyPrivateVoting::at(voting_contract_address).delegate_vote(delegatee, random).call(&mut env.private());

//     env.impersonate(carl);
//     env.advance_block_by(1);
//     EasyPrivateVoting::at(voting_contract_address).delegate_vote(delegatee, random).call(&mut env.private());

//     // NOTE: the limit of delegations per `cast_delegated_vote` is set to 3
//     env.impersonate(dave);
//     env.advance_block_by(1);
//     EasyPrivateVoting::at(voting_contract_address).delegate_vote(delegatee, random).call(&mut env.private());

//     env.impersonate(delegatee);
//     env.advance_block_by(1);
//     EasyPrivateVoting::at(voting_contract_address).cast_delegated_vote(candidate).call(&mut env.private());

//     // Read vote count from storage
//     let mut block_number = get_block_number();
//     let tally_slot = EasyPrivateVoting::storage_layout().tally.slot;
//     let candidate_tally_slot = derive_storage_slot_in_map(tally_slot, candidate);
//     let mut vote_count: u32 = storage_read(voting_contract_address, candidate_tally_slot, block_number);

//     assert(vote_count == 300, "vote tally should be 300");

//     env.impersonate(delegatee);
//     env.advance_block_by(1);
//     EasyPrivateVoting::at(voting_contract_address).cast_delegated_vote(candidate).call(&mut env.private());

//     block_number = get_block_number();
//     vote_count = storage_read(voting_contract_address, candidate_tally_slot, block_number);

//     assert(vote_count == 400, "vote tally should be 400");
// }

// #[test(should_fail)]
// unconstrained fn test_fail_vote_twice() {
//     let (env, voting_contract_address, token_contract_address, admin) = utils::setup();
//     let alice = env.create_account();

//     let candidate = 101;

//     env.impersonate(admin);
//     Token::at(token_contract_address).mint_to_private( admin, alice, 100).call(&mut env.private());

//     env.impersonate(alice);
//     env.advance_block_by(1);
//     EasyPrivateVoting::at(voting_contract_address).cast_vote(candidate).call(&mut env.private());

//     // Vote again as alice
//     env.advance_block_by(1);
//     EasyPrivateVoting::at(voting_contract_address).cast_vote(candidate).call(&mut env.private());
// }

// #[test(should_fail)]
// unconstrained fn test_fail_delegate_and_vote() {
//     let (env, voting_contract_address, token_contract_address, admin) = utils::setup();
//     let alice = env.create_account();
//     let bob = env.create_account();

//     let candidate = 101;
//     let random = 420;

//     env.impersonate(admin);
//     Token::at(token_contract_address).mint_to_private( admin, alice, 100).call(&mut env.private());

//     env.impersonate(alice);
//     env.advance_block_by(1);
//     EasyPrivateVoting::at(voting_contract_address).delegate_vote(bob, random).call(&mut env.private());

//     // Vote again as alice
//     env.advance_block_by(1);
//     EasyPrivateVoting::at(voting_contract_address).cast_vote(candidate).call(&mut env.private());
// }

// #[test(should_fail)]
// unconstrained fn test_fail_vote_and_delegate() {
//     let (env, voting_contract_address, token_contract_address, admin) = utils::setup();
//     let alice = env.create_account();
//     let bob = env.create_account();

//     let candidate = 101;
//     let random = 420;

//     env.impersonate(admin);
//     Token::at(token_contract_address).mint_to_private( admin, alice, 100).call(&mut env.private());
//     Token::at(token_contract_address).mint_to_private( admin, bob, 100).call(&mut env.private());

//     env.impersonate(alice);
//     env.advance_block_by(1);
//     EasyPrivateVoting::at(voting_contract_address).cast_vote(candidate).call(&mut env.private());

//     // Delegate vote as alice
//     env.advance_block_by(1);
//     EasyPrivateVoting::at(voting_contract_address).delegate_vote(bob, random).call(&mut env.private());
// }

fn prepare_authwit(
    token: AztecAddress,
    caller: AztecAddress,
    owner: AztecAddress,
    amount: Field,
    nonce: Field,
) {
    // NOTE: prepares authwit
    let transfer_private_from_call_interface =
        Token::at(token).transfer_in_private(owner, owner, U128::from_field(amount), nonce);
    authwit_cheatcodes::add_private_authwit_from_call_interface(
        owner,
        caller,
        transfer_private_from_call_interface,
    );
}
