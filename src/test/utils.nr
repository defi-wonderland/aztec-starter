use dep::aztec::{prelude::AztecAddress, test::helpers::test_environment::TestEnvironment};

use crate::EasyPrivateVoting;

pub unconstrained fn setup() -> (&mut TestEnvironment, AztecAddress, AztecAddress) {
    let mut env = TestEnvironment::new();

    let admin = env.create_account(0);
    let contract_secret = 420;

    let initializer_call_interface = EasyPrivateVoting::interface().constructor(admin);
    let voting_contract = env.deploy_self_with_public_keys("EasyPrivateVoting", contract_secret).with_public_void_initializer(
        initializer_call_interface,
    );

    env.advance_block_by(1);
    (&mut env, voting_contract.to_address(), admin)
}
