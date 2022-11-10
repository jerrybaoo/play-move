// Copyright (c) Developer.
// SPDX-License-Identifier: Apache-2.0

use super::*;

use sui_framework::build_move_package;
use sui_framework_build::compiled_package::BuildConfig;
use sui_json::SuiJsonValue;
use sui_keys::keystore::{AccountKeystore, FileBasedKeystore, Keystore};
use sui_sdk::types::messages::Transaction;

use primitives::*;

pub struct Server {
    keystore: Keystore,
    chain_client: SuiClient,
}

impl Server {
    pub async fn new(url: &str, keystore_path: PathBuf) -> Result<Self, anyhow::Error> {
        let client = SuiClient::new(url, None, None).await?;
        let keystore = Keystore::File(FileBasedKeystore::new(&keystore_path)?);

        return Ok(Self {
            keystore,
            chain_client: client,
        });
    }

    pub async fn publish_package(&self, package_path: &PathBuf) -> Result<String, anyhow::Error> {
        let sender = *self
            .keystore
            .addresses()
            .first()
            .ok_or(anyhow!("keystore has't addresses"))?;

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
            .publish(sender, compiled_modules, None, 20000)
            .await?;

        let signature = self.keystore.sign(&sender, &publish_call.to_bytes())?;

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

        let effect = response
            .effects
            .ok_or(anyhow!("publish package no effects, please check"))?;

        let immutable = effect
            .created
            .iter()
            .filter(|&c| c.owner.is_immutable())
            .collect::<Vec<_>>();

        let expansion_package_id = immutable
            .first()
            .ok_or(anyhow!(
                "no immutable objected, publish expansion maybe failed"
            ))?
            .reference
            .object_id;

        // should write it into log?
        let expansion_package_id_hex = expansion_package_id.to_hex_literal();
        println!(
            "published expansion package id {}",
            &expansion_package_id_hex
        );

        Ok(expansion_package_id_hex)
    }

    pub async fn create_scene(
        &self,
        package_object_id_hex: String,
        params: &CreateSceneParameter,
    ) -> Result<(), anyhow::Error> {
        let sender = *self
            .keystore
            .addresses()
            .first()
            .ok_or(anyhow!("keystore has't addresses"))?;

        
        let v3 = serde_json::to_value::<u64>(params.min_stake_amount)?;
        let arg3 = SuiJsonValue::new(v3)?;

        let create_scene_call = self
            .chain_client
            .transaction_builder()
            .move_call(
                sender,
                ObjectID::from_hex_literal(&package_object_id_hex)?,
                "scenes",
                "create_scene",
                vec![],
                vec![arg3],
                None,
                300000,
            )
            .await?;

        let signature = self.keystore.sign(&sender, &create_scene_call.to_bytes())?;

        let response = self
            .chain_client
            .quorum_driver()
            .execute_transaction(
                Transaction::new(create_scene_call, signature).verify()?,
                Some(
                    sui_sdk::types::messages::ExecuteTransactionRequestType::WaitForLocalExecution,
                ),
            )
            .await?;

        println!("{:#?}", response);

        Ok(())
    }
}

pub fn mock_scene() -> CreateSceneParameter {
    CreateSceneParameter {
        energy_source: EnergySource {
            power: 100000,
            radius: 2000,
            equilibrium: 90,
        },
        scene_parameter: SceneParameter {
            frames: 1,
            frame_interval: 1,
            next_frame_block: 10,
            max_participant: 10,
        },
        min_stake_amount: 0,
    }
}

#[cfg(test)]
mod test {
    use crate::primitives::{CreateSceneParameter, EnergySource, SceneParameter};

    #[test]
    fn create_scene_should_work() {
        let params = CreateSceneParameter {
            energy_source: EnergySource {
                power: 100000,
                radius: 2000,
                equilibrium: 90,
            },
            scene_parameter: SceneParameter {
                frames: 1,
                frame_interval: 1,
                next_frame_block: 10,
                max_participant: 10,
            },
            min_stake_amount: 0,
        };
    }
}
