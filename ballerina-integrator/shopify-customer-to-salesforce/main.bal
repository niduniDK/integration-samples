import ballerina/log;
import ballerinax/trigger.shopify;

// Shopify webhook listener configuration
listener shopify:Listener shopifyListener = new ({
    "port": 8090,
    "apiSecretKey": shopifyConfig.shopifySecret
});

function handleCustomerCreateOrUpdate(
    shopify:CustomerEvent event,
    string receivedLog,
    string successLog,
    string? errorLog = ()
) returns error? {
    int? eventId = event?.id;
    log:printInfo(receivedLog, customerId = eventId.toString());

    error? result = createOrUpdateSalesforceContact(event);
    if result is error {
        if errorLog is string {
            log:printError(errorLog, 'error = result, customerId = eventId.toString());
        }
        return result;
    }

    log:printInfo(successLog, customerId = eventId.toString());
}

// Shopify webhook service to handle events

service shopify:CustomersService on shopifyListener {

    remote function onCustomersCreate(shopify:CustomerEvent event) returns error? {
        return handleCustomerCreateOrUpdate(
            event,
            "Received customer created event",
            "Successfully processed customer created event",
            "Failed to create or update Salesforce contact"
        );
    }

    remote function onCustomersUpdate(shopify:CustomerEvent event) returns error? {
        return handleCustomerCreateOrUpdate(
            event,
            "Received customer updated event",
            "Successfully processed customer updated event"
        );
    }

    remote function onCustomersDelete(shopify:CustomerEvent event) returns error? {
        int? eventId = event?.id;
        log:printWarn("Customer deleted", customerId = eventId.toString());
    }

    remote function onCustomersDisable(shopify:CustomerEvent event) returns error? {
        int? eventId = event?.id;
        log:printInfo("Customer disabled", customerId = eventId.toString());
    }

    remote function onCustomersEnable(shopify:CustomerEvent event) returns error? {
        int? eventId = event?.id;
        log:printInfo("Customer enabled", customerId = eventId.toString());
    }

    remote function onCustomersMarketingConsentUpdate(shopify:CustomerEvent event) returns error? {
        int? eventId = event?.id;
        log:printInfo("Customer marketing consent updated", customerId = eventId.toString());
    }
}