use sui_json::SuiJsonValue;

use proc_macro_crate::ExactSuiJsonValue;

#[derive(ExactSuiJsonValue)]
struct MacroTest {
    bar: u64,
    foo: u64,
}

#[test]
fn exact_sui_json_value_shouldwork() {
    let m1 = MacroTest { bar: 20, foo: 21 };
    let res = m1.fields_to_sui_values().unwrap();

    assert_eq!(
        SuiJsonValue::new(serde_json::to_value::<u64>(20).unwrap()).unwrap(),
        res[0]
    );
}
