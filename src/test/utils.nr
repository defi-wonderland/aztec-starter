use dep::authwit::cheatcodes as authwit_cheatcodes;
use dep::aztec::{
    oracle::execution::get_contract_address,
    prelude::AztecAddress,
    test::helpers::{cheatcodes, test_environment::TestEnvironment},
};
use dep::token::Token;

use crate::EasyPrivateVoting;

pub unconstrained fn setup() -> (&mut TestEnvironment, AztecAddress, AztecAddress, AztecAddress) {
    let mut env = TestEnvironment::new();

    let admin = env.create_account_contract(1000);

    env.impersonate(admin);
    let token_initializer_call_interface = Token::interface().constructor(
        admin,
        "NAME___________________________", // NOTE: expects str<31>
        "SYMBOL_________________________",
        18 as u8,
    );

    let token_contract = env.deploy("./@token_contract", "Token").with_public_void_initializer(
        token_initializer_call_interface,
    );
    env.advance_block_by(1);

    let initializer_call_interface =
        EasyPrivateVoting::interface().constructor(admin, token_contract.to_address());
    let voting_contract = env.deploy_self("EasyPrivateVoting").with_public_void_initializer(
        initializer_call_interface,
    );
    env.advance_block_by(1);

    (&mut env, voting_contract.to_address(), token_contract.to_address(), admin)
}

pub unconstrained fn prepare_token_balance_and_authwit(
    env: &mut TestEnvironment,
    voting_contract_address: AztecAddress,
    token_contract_address: AztecAddress,
    admin: AztecAddress,
    owner: AztecAddress,
    amount: U128,
) {
    prepare_token_balance(env, token_contract_address, admin, owner, amount);
    prepare_authwit(
        token_contract_address,
        voting_contract_address,
        owner,
        100,
        1,
    );
}

pub unconstrained fn prepare_token_balance(
    env: &mut TestEnvironment,
    token_contract_address: AztecAddress,
    admin: AztecAddress,
    owner: AztecAddress,
    amount: U128,
) {
    env.impersonate(admin);
    Token::at(token_contract_address).mint_to_private(owner, owner, amount).call(&mut env.private());
    env.advance_block_by(1);
}

pub unconstrained fn prepare_authwit(
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
