import ballerina/log;
import ballerinax/trigger.shopify;
import ballerinax/salesforce;

// Map Shopify customer event to Salesforce contact with all available fields
public function mapShopifyCustomerToSalesforceContact(
    shopify:CustomerEvent customerEvent,
    string? accountId = ()
) returns SalesforceContact {

    string? firstName = customerEvent?.first_name;
    string? lastName = customerEvent?.last_name;
    string? email = customerEvent?.email;
    string? phone = customerEvent?.phone;

    string normalizedLastName = lastName is string && lastName.trim() != "" ? lastName : "Unknown";

    SalesforceContact contact = {
        LastName: normalizedLastName,
        FirstName: firstName,
        Email: email,
        Phone: phone,
        AccountId: accountId
    };

    json defaultAddressJson = <json>customerEvent["default_address"];
    if defaultAddressJson is map<json> {
        string address1 = defaultAddressJson["address1"] is string ? <string>defaultAddressJson["address1"] : "";
        string address2 = defaultAddressJson["address2"] is string ? <string>defaultAddressJson["address2"] : "";
        string city = defaultAddressJson["city"] is string ? <string>defaultAddressJson["city"] : "";
        string province = defaultAddressJson["province"] is string ? <string>defaultAddressJson["province"] : "";
        string zip = defaultAddressJson["zip"] is string ? <string>defaultAddressJson["zip"] : "";
        string country = defaultAddressJson["country"] is string ? <string>defaultAddressJson["country"] : "";
        string addrPhone = defaultAddressJson["phone"] is string ? <string>defaultAddressJson["phone"] : "";

        contact.MailingStreet = address1 + (address2 != "" ? ", " + address2 : "");
        contact.MailingCity = city;
        contact.MailingState = province;
        contact.MailingPostalCode = zip;
        contact.MailingCountry = country;

        if phone is string {
            contact.Phone = phone;
        } else {
            contact.Phone = addrPhone;
        }

        if phone is string && addrPhone != "" && phone != addrPhone {
            contact.OtherPhone = addrPhone;
        }
    }

    json emailMarketingConsentJson = <json>customerEvent["email_marketing_consent"];
    if emailMarketingConsentJson is map<json> {
        json stateVal = emailMarketingConsentJson["state"];
        if stateVal is string {
            contact.HasOptedOutOfEmail = stateVal != "subscribed";
        }
    }

    json smsMarketingConsentJson = <json>customerEvent["sms_marketing_consent"];
    if smsMarketingConsentJson is map<json> {
        json stateVal = smsMarketingConsentJson["state"];
        if stateVal is string {
            contact.DoNotCall = stateVal != "subscribed";
        }
    }

    string enrichedDescription = buildCustomerDescription(customerEvent);
    contact.Description = enrichedDescription;

    return contact;
}

// Build description
function buildCustomerDescription(shopify:CustomerEvent customerEvent) returns string {
    json idVal = customerEvent["id"];
    int customerId = idVal is int ? idVal : 0;

    string[] descriptionParts = [];

    descriptionParts.push("Shopify Customer ID: " + customerId.toString());

    json totalSpent = customerEvent["total_spent"];
    descriptionParts.push("Total Spent: " + (totalSpent is (int|string) ? totalSpent.toString() : ""));

    json orders = customerEvent["orders_count"];
    descriptionParts.push("Orders Count: " + (orders is (int|string) ? orders.toString() : ""));

    descriptionParts.push("State: " + (customerEvent["state"] is string ? <string>customerEvent["state"] : ""));

    boolean verified = customerEvent["verified_email"] is boolean ? <boolean>customerEvent["verified_email"] : false;
    descriptionParts.push("Email Verified: " + verified.toString());

    boolean tax = customerEvent["tax_exempt"] is boolean ? <boolean>customerEvent["tax_exempt"] : false;
    descriptionParts.push("Tax Exempt: " + tax.toString());

    descriptionParts.push("Tags: " + (customerEvent["tags"] is string ? <string>customerEvent["tags"] : ""));

    string note = customerEvent["note"] is string ? <string>customerEvent["note"] : "";
    descriptionParts.push("Note: " + (note.length() > 100 ? note.substring(0, 97) + "..." : note));

    descriptionParts.push("Currency: " + (customerEvent["currency"] is string ? <string>customerEvent["currency"] : ""));

    json emailConsent = <json>customerEvent["email_marketing_consent"];
    if emailConsent is map<json> {
        descriptionParts.push("Email Marketing: " + (emailConsent["state"] is string ? <string>emailConsent["state"] : ""));
        descriptionParts.push("Email Consent Updated: " + (emailConsent["consent_updated_at"] is string ? <string>emailConsent["consent_updated_at"] : ""));
    }

    json smsConsent = <json>customerEvent["sms_marketing_consent"];
    if smsConsent is map<json> {
        descriptionParts.push("SMS Marketing: " + (smsConsent["state"] is string ? <string>smsConsent["state"] : ""));
        descriptionParts.push("SMS Consent Updated: " + (smsConsent["consent_updated_at"] is string ? <string>smsConsent["consent_updated_at"] : ""));
    }

    descriptionParts.push("Created: " + (customerEvent["created_at"] is string ? <string>customerEvent["created_at"] : ""));
    descriptionParts.push("Updated: " + (customerEvent["updated_at"] is string ? <string>customerEvent["updated_at"] : ""));

    return string:'join(" | ", ...descriptionParts);
}

// Add Shopify tag to contact after creation/update
public function addShopifyTagToContact(string contactId) returns error? {
    // Create tag for Shopify origin
    salesforce:CreationResponse|error tagResponse = salesforceClient->create(
        sObjectName = "Tag",
        sObject = {
            "Name": "Shopify",
            "Type": "Public"
        }
    );
    
    string tagId = "";
    if tagResponse is salesforce:CreationResponse {
        if tagResponse.success {
            tagId = tagResponse.id;
            log:printInfo("Created Shopify tag", tagId = tagId);
        } 
    } else {
        // Tag might already exist, try to find it
        string soqlQuery = "SELECT Id FROM Tag WHERE Name = 'Shopify' LIMIT 1";
        stream<record {| string Id; |}, error?> resultStream = check salesforceClient->query(soql = soqlQuery);
        
        record {|record {| string Id; |} value;|}? result = check resultStream.next();
        check resultStream.close();
        
        if result is record {|record {| string Id; |} value;|} {
            tagId = result.value.Id;
            log:printInfo("Found existing Shopify tag", tagId = tagId);
        } else {
            log:printError("Failed to create or find Shopify tag");
            return;
        }
    }
    
    // Associate tag with contact
    salesforce:CreationResponse|error tagAssocResult = salesforceClient->create(
        sObjectName = "TagDefinition",
        sObject = {
            "TagId": tagId,
            "EntityId": contactId,
            "Type": "Contact"
        }
    );
    
    if tagAssocResult is error {
        log:printError("Failed to associate tag with contact", 'error = tagAssocResult);
        return tagAssocResult;
    }
    
    if tagAssocResult is salesforce:CreationResponse && !tagAssocResult.success {
        log:printError("Failed to associate tag with contact", errors = tagAssocResult.errors);
        return error("Failed to associate tag");
    }
    
    log:printInfo("Successfully tagged contact as Shopify origin", contactId = contactId);
}


// Fixing extractDomainFromEmail function
public function extractDomainFromEmail(string email) returns string? {
    int? atIndex = email.indexOf("@");
    if atIndex is int && atIndex > 0 && atIndex < email.length() - 1 {
        string domain = email.substring(atIndex + 1).trim();
        if domain != "" {
            return domain;
        }
    }
    return ();
}

// Extract company name from customer event
public function extractCompanyName(shopify:CustomerEvent customerEvent) returns string? {
    json customerJson = <json>customerEvent.toJson();
    
    // Extract company from default address
    json|error defaultAddressJson = customerJson.default_address;
    if defaultAddressJson is json && defaultAddressJson != () {
        json|error companyJson = defaultAddressJson.company;
        if companyJson is string && companyJson.trim() != "" {
            return companyJson;
        }
    }
    
    return ();
}