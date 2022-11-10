// Copyright (c) Developer.
// SPDX-License-Identifier: Apache-2.0

// A centralized service provided to expansion player.

mod primitives;
mod server;

use std::path::PathBuf;

use anyhow::anyhow;
use clap::Parser;
use clap::Subcommand;
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
}

#[tokio::main]
async fn main() -> Result<(), anyhow::Error> {
    let opts = ExpansionOpts::parse();

    let server = Server::new(&opts.rpc_server_url, opts.keystore_path).await?;

    match opts.subcommand {
        ExpansionCommand::Publish { package_path } => {
            server.publish_package(&package_path).await?;
        }
        ExpansionCommand::Start {
            expansion_package_id,
        } => {
            server
                .create_scene(expansion_package_id, &server::mock_scene())
                .await?;
        }
    };

    Ok(())
}
