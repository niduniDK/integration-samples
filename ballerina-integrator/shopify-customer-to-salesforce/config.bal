public type ShopifyConfig record {|
    // This should be the webhook secret from Shopify (used for HMAC SHA256 validation)
    string shopifySecret;
|};

public enum AccountAssociationRule {
    COMPANY = "company",
    DOMAIN = "domain",
    NONE = "none"
}

public type SalesforceConfig record {|
    // Salesforce OAuth2 configuration
    string salesforceBaseUrl;
    string salesforceClientId;
    string salesforceClientSecret;
    string salesforceRefreshToken;
    string salesforceRefreshUrl = "https://login.salesforce.com/services/oauth2/token";

    AccountAssociationRule accountAssociationRule = COMPANY;
|};

configurable ShopifyConfig shopifyConfig = ?;
configurable SalesforceConfig salesforceConfig = ?;
