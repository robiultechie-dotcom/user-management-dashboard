# Force invalidate all previous browser session cookies across all clients
Rails.application.config.session_store :cookie_store, key: '_user_mgmt_production_v3_session'