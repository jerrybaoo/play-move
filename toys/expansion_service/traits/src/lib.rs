// Copyright (c) Developer.
// SPDX-License-Identifier: Apache-2.0

pub trait DoExactSuiJsonValue {
    fn fields_to_sui_values(&self) -> Result<Vec<sui_json::SuiJsonValue>, anyhow::Error>;
}
