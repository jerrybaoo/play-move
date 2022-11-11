// Copyright (c) Developer.
// SPDX-License-Identifier: Apache-2.0

// A centralized service provided to expansion player.

mod primitives;
mod server;

#[cfg(test)]
pub mod test;

use std::path::PathBuf;

use anyhow::anyhow;
use clap::Parser;
use clap::Subcommand;
use primitives::*;
use sui_sdk::{types::base_types::ObjectID, SuiClient};

use server::*;

// Clap command line args parser
#[derive(Parser, Debug)]
#[clap(name = "expansion", about = "expansion player service")]
struct ExpansionOpts {
    #[clap(long, help = "keystore used to sign all transcations")]
    keystore_path: PathBuf,

    #[clap(long, help = "the block chain node will connect")]
    rpc_server_url: String,

    #[clap(subcommand)]
    subcommand: ExpansionCommand,
}

#[derive(Subcommand, Debug)]
enum ExpansionCommand {
    #[clap(about = "publish package in specied path")]
    Publish {
        #[clap(long)]
        package_path: PathBuf,
    },
    #[clap(about = "start service with published package")]
    Start {
        #[clap(long)]
        expansion_package_id: String,
    },
    #[clap(about = "get xcoin, which is the game chip ")]
    MintXCoin {
        #[clap(long)]
        expansion_package_id: String,
        #[clap(long)]
        xcoin_object_id: String,
        #[clap(long)]
        amount: u64,
        #[clap(long)]
        target: String,
    },
    #[clap(about = "enter scene by stake some xcoin")]
    Enter {
        expansion_package_id: String,
        scene_object_id: String,
        stake_xcoin_id: String,
        participant: String,
    },
}

#[tokio::main]
async fn main() -> Result<(), anyhow::Error> {
    let opts = ExpansionOpts::parse();

    let server = Server::new(&opts.rpc_server_url, opts.keystore_path).await?;

    match opts.subcommand {
        ExpansionCommand::Publish { package_path } => {
            let (publish_package_id, xcode_object_id) =
                server.publish_package(&package_path).await?;

            println!(
                "publish package id: {}, xcoin_object_id {}",
                publish_package_id, xcode_object_id
            );
        }
        ExpansionCommand::Start {
            expansion_package_id,
        } => {
            let create_scene_object_id = server
                .create_scene(expansion_package_id, &server::mock_scene())
                .await?;

            println!("create scene object id: {}", create_scene_object_id)
        }
        ExpansionCommand::MintXCoin {
            expansion_package_id,
            xcoin_object_id,
            amount,
            target,
        } => {
            let params = CoinMintParameter {
                object_id: xcoin_object_id,
                amount,
                recipient: target,
            };
            server.mint_xcoin(expansion_package_id, &params).await?;
        }
        ExpansionCommand::Enter {
            expansion_package_id,
            scene_object_id,
            stake_xcoin_id,
            participant,
        } => {
            server
                .enter(
                    expansion_package_id,
                    &EnterParameter {
                        scene_object_id,
                        stake_xcoin_id,
                        participant,
                    },
                )
                .await?;
        }
    };

    Ok(())
}
