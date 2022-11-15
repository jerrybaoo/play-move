// Copyright (c) Developer.
// SPDX-License-Identifier: Apache-2.0

use std::fmt::Debug;

use super::*;

use serde::Deserialize;
use sui_framework::build_move_package;
use sui_framework_build::compiled_package::BuildConfig;
use sui_json_rpc_types::SuiData;
use sui_keys::keystore::{AccountKeystore, FileBasedKeystore, Keystore};
use sui_sdk::{
    types::{base_types::SuiAddress, messages::Transaction},
    TransactionExecutionResult,
};

use traits::DoExactSuiJsonValue;

use primitives::*;

pub struct Server {
    keystore: Keystore,
    chain_client: SuiClient,
    sender: SuiAddress,
}

impl Server {
    pub async fn new(url: &str, keystore_path: PathBuf) -> Result<Self, anyhow::Error> {
        let client = SuiClient::new(url, None, None).await?;
        let keystore = Keystore::File(FileBasedKeystore::new(&keystore_path)?);
        let sender = *keystore
            .addresses()
            .first()
            .ok_or(anyhow!("keystore has't addresses"))?;

        return Ok(Self {
            keystore,
            chain_client: client,
            sender,
        });
    }

    pub async fn publish_package(
        &self,
        package_path: &PathBuf,
    ) -> Result<(String, String), anyhow::Error> {
        let compiled_modules = build_move_package(
            package_path,
            BuildConfig {
                config: Default::default(),
                run_bytecode_verifier: true,
                print_diags_to_stderr: true,
            },
        )?
        .get_package_bytes();

        let publish_call = self
            .chain_client
            .transaction_builder()
            .publish(self.sender, compiled_modules, None, 20000)
            .await?;

        let signature = self.keystore.sign(&self.sender, &publish_call.to_bytes())?;

        let response = self
            .chain_client
            .quorum_driver()
            .execute_transaction(
                Transaction::new(publish_call, signature).verify()?,
                Some(
                    sui_sdk::types::messages::ExecuteTransactionRequestType::WaitForLocalExecution,
                ),
            )
            .await?;

        // println!("{:#?}", response);

        let effect = response
            .effects
            .ok_or(anyhow!("publish package no effects, please check"))?;

        let immutable = effect
            .created
            .iter()
            .filter(|&c| c.owner.is_immutable())
            .collect::<Vec<_>>();

        let mutable = effect
            .created
            .iter()
            .filter(|&c| !c.owner.is_immutable())
            .collect::<Vec<_>>();

        let expansion_package_id = immutable
            .first()
            .ok_or(anyhow!(
                "no immutable objected, publish expansion maybe failed"
            ))?
            .reference
            .object_id;

        let xcode_object_id = mutable
            .first()
            .ok_or(anyhow!(
                "no mutable objected, publish expansion maybe failed"
            ))?
            .reference
            .object_id;

        // should write it into log?
        let expansion_package_id_hex = expansion_package_id.to_hex_literal();
        let xcode_object_id_hex = xcode_object_id.to_hex_literal();

        Ok((expansion_package_id_hex, xcode_object_id_hex))
    }

    pub async fn create_scene(
        &self,
        package_object_id_hex: String,
        params: &CreateSceneParameter,
    ) -> Result<String, anyhow::Error> {
        let response = self
            .send_and_wait_transaction(package_object_id_hex, "scenes", "create_scene", params)
            .await?;

        let created_object = response
            .effects
            .ok_or(anyhow!("create scene failed"))?
            .created;

        if created_object.len() != 1 {
            return Err(anyhow!(
                "`create_scene` generate more than one object, please check"
            ));
        }
        let create_scene_object_id_hex = created_object
            .get(0)
            .ok_or(anyhow!("get created object failed from `create_scene`"))?
            .reference
            .object_id
            .to_hex_literal();

        Ok(create_scene_object_id_hex)
    }

    pub async fn mint_xcoin(
        &self,
        package_object_id_hex: String,
        params: &CoinMintParameter,
    ) -> Result<(), anyhow::Error> {
        let response = self
            .send_and_wait_transaction::<CoinMintParameter>(
                package_object_id_hex,
                "xcoin",
                "mint",
                params,
            )
            .await?;

        println!("{:#?}", *response);

        Ok(())
    }

    pub async fn enter(
        &self,
        package_object_id_hex: String,
        params: &EnterParameter,
    ) -> Result<(), anyhow::Error> {
        self.send_and_wait_transaction(
            package_object_id_hex,
            "scenes",
            "participant_enter",
            params,
        )
        .await?;

        println!("{:#?}", response);

        Ok(())
    }

    async fn send_and_wait_transaction<T: DoExactSuiJsonValue>(
        &self,
        package_object_id_hex: String,
        module: &str,
        function: &str,
        params: &T,
    ) -> Result<Box<TransactionExecutionResult>, anyhow::Error> {
        let call = self
            .chain_client
            .transaction_builder()
            .move_call(
                self.sender,
                ObjectID::from_hex_literal(&package_object_id_hex)?,
                module,
                function,
                vec![],
                params.fields_to_sui_values()?,
                None,
                300000,
            )
            .await?;

        let signature = self.keystore.sign(&self.sender, &call.to_bytes())?;

        let response = self
            .chain_client
            .quorum_driver()
            .execute_transaction(
                Transaction::new(call, signature).verify()?,
                Some(
                    sui_sdk::types::messages::ExecuteTransactionRequestType::WaitForLocalExecution,
                ),
            )
            .await?;
        Ok(Box::new(response))
    }

    pub async fn fetch_object_state<T: for<'a> Deserialize<'a> + Debug>(
        &self,
        id: &str,
    ) -> Result<T, anyhow::Error> {
        let object_id = ObjectID::from_hex_literal(id)?;
        let object = self.chain_client.read_api().get_object(object_id).await?;
        object
            .object()?
            .data
            .try_as_move()
            .ok_or(anyhow!("try as move failed"))?
            .deserialize()
    }
}

pub fn mock_scene() -> CreateSceneParameter {
    CreateSceneParameter {
        power: 100000,
        radius: 2000,
        equilibrium: 90,
        frames: 1,
        frame_interval: 1,
        next_frame_block: 10,
        max_participant: 10,

        min_stake_amount: 0,
    }
}
