use flutter_rust_bridge::frb;

pub mod nostr;
pub mod sdk;

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}
