// Copyright (c) Developer.
// SPDX-License-Identifier: Apache-2.0

use proc_macro::TokenStream;
use quote::quote;
use syn;

type StructFields = syn::punctuated::Punctuated<syn::Field, syn::Token!(,)>;

// ExactSuiJsonValue convert struct filed to SuiJsonValue array.
// Usually we get a contract and use the corresponding json object,
// first deserialize it into a struct, and then convert this object into a SuiJsonValue List.
// With this macro any object can be quickly converted to SuiJsonValue Vector.
#[proc_macro_derive(ExactSuiJsonValue)]
pub fn derive(input: TokenStream) -> TokenStream {
    let st = syn::parse_macro_input!(input as syn::DeriveInput);
    match do_expand(&st) {
        Ok(token_stream) => token_stream.into(),
        Err(e) => e.to_compile_error().into(),
    }
}

fn do_expand(st: &syn::DeriveInput) -> syn::Result<proc_macro2::TokenStream> {
    let struct_ident = &st.ident;
    let fields = get_fields_from_derive_input(st)?;

    let idents: Vec<_> = fields.iter().map(|f| &f.ident).collect();
    let types: Vec<_> = fields.iter().map(|f| &f.ty).collect();

    let ret = quote! {
        impl #struct_ident{
            pub fn fields_to_sui_values(&self)->Result<Vec<sui_json::SuiJsonValue>, anyhow::Error>{
                let mut values = Vec::new();
                #(values.push(sui_json::SuiJsonValue::new(serde_json::to_value::<#types>(self.#idents)?)?);)*
                Ok(values)
            }
        }
    };

    Ok(ret)
}

fn get_fields_from_derive_input(d: &syn::DeriveInput) -> syn::Result<&StructFields> {
    if let syn::Data::Struct(syn::DataStruct {
        fields: syn::Fields::Named(syn::FieldsNamed { ref named, .. }),
        ..
    }) = d.data
    {
        return Ok(named);
    }
    Err(syn::Error::new_spanned(
        d,
        "Must define on a Struct, not Enum".to_string(),
    ))
}
