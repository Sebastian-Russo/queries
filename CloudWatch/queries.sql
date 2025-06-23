
------------------------------------------------------------------------------------------------------------------
-- Query 1
-- Extract Specific Attributes Key/Value Pair
-- Purpose: Retrieves details of attributes set in flows, including the contact ID, flow name, and key-value pairs.
-- Strengths: Captures essential fields for auditing specific attribute settings.
------------------------------------------------------------------------------------------------------------------
fields @timestamp, ContactId, ContactFlowName, Identifier, Parameters.EventName, Parameters.Key, Parameters.Value
| filter ContactFlowModuleType = "SetAttributes"
| sort @timestamp desc
| limit 1000
------------------------------------------------------------------------------------------------------------------



------------------------------------------------------------------------------------------------------------------
-- Query 2
-- Count by Attribute Name
-- Purpose: Counts how often each attribute key is set, helping identify frequently used attributes.
-- Strengths: Simple aggregation to reveal attribute usage patterns.
------------------------------------------------------------------------------------------------------------------
fields @timestamp
| filter ContactFlowModuleType = "SetAttributes"
| stats count() as attributeCount by Parameters.Key
| sort attributeCount desc
| filter @timestamp >= -24h
------------------------------------------------------------------------------------------------------------------


------------------------------------------------------------------------------------------------------------------
-- Query 3
-- Count by Attributes Key/Value Combo
-- Purpose: Counts occurrences of specific key-value pairs, useful for understanding attribute value distribution.
-- Strengths: Provides granular insights into attribute settings.
------------------------------------------------------------------------------------------------------------------
fields @timestamp
| filter ContactFlowModuleType = "SetAttributes"
| stats count() as comboCount by Parameters.Key, Parameters.Value
| sort comboCount desc
-- | filter Parameters.Key in ["greetingPlayed", "customerType"]
------------------------------------------------------------------------------------------------------------------


------------------------------------------------------------------------------------------------------------------
-- Query 4
-- Count by Flow Name and Attribute Combo
-- Purpose: Analyzes attribute usage by contact flow, useful for debugging or optimizing specific flows.
-- Strengths: Links attributes to flows, aiding in flow-specific analysis.
------------------------------------------------------------------------------------------------------------------
fields @timestamp
| filter ContactFlowModuleType = "SetAttributes"
| stats count() as flowAttributeCount by ContactFlowName, Parameters.Key
| sort flowAttributeCount desc
| filter @timestamp >= -7d
------------------------------------------------------------------------------------------------------------------


-- Addition queries
------------------------------------------------------------------------------------------------------------------
-- Query 5
-- Discover All Attribute Keys Across All Module Types
-- Purpose: Identifies all attribute keys logged in CloudWatch, not just those from SetAttributes, to uncover system or external attributes (e.g., from Lambda or Lex).
-- Use Case: Helps build an inventory of all attributes used in your contact center.
------------------------------------------------------------------------------------------------------------------
fields @timestamp, ContactId, ContactFlowModuleType, Parameters.Key, Parameters.Value
| filter ispresent(Parameters.Key)
| stats count() as keyCount by Parameters.Key, ContactFlowModuleType
| sort keyCount desc
| limit 100
------------------------------------------------------------------------------------------------------------------


------------------------------------------------------------------------------------------------------------------
-- Query 6
-- Extract System Attributes from Contact Events
-- Purpose: Captures system attributes logged during contact lifecycle events (e.g., CustomerEndpoint.Address, InitiationMethod).
-- Use Case: Useful for identifying system attributes not explicitly set in flows but available in contact records.
------------------------------------------------------------------------------------------------------------------
fields @timestamp, ContactId, Parameters.EventName, Parameters
| filter Parameters.EventName in ["INITIATED", "QUEUED", "CONNECTED_TO_AGENT", "DISCONNECTED"]
| parse @message '"Parameters": *' as params
| display @timestamp, ContactId, Parameters.EventName, params
| limit 100
------------------------------------------------------------------------------------------------------------------


------------------------------------------------------------------------------------------------------------------
-- Query 7
-- Identify Attributes Set by External Sources (e.g., Lambda, Lex)
-- Purpose: Focuses on attributes returned by Lambda functions or Amazon Lex bots, which are often stored as contact attributes.
-- Use Case: Helps discover attributes like $.Lex.Slots.slotName or Lambda-returned key-value pairs.
------------------------------------------------------------------------------------------------------------------
fields @timestamp, ContactId, ContactFlowModuleType, Parameters.Key, Parameters.Value
| filter ContactFlowModuleType in ["InvokeLambda", "GetCustomerInput"]
| filter ispresent(Parameters.Key)
| stats count() by Parameters.Key, Parameters.Value, ContactFlowModuleType
| sort @count desc
------------------------------------------------------------------------------------------------------------------


------------------------------------------------------------------------------------------------------------------
-- Query 8
-- Track Attribute Changes for a Specific Contact
-- Purpose: Traces all attribute changes for a single contact, useful for debugging specific interactions.
-- Use Case: Diagnose why certain attributes aren’t behaving as expected in a flow.
------------------------------------------------------------------------------------------------------------------
fields @timestamp, ContactFlowName, Parameters.Key, Parameters.Value
| filter ContactFlowModuleType = "SetAttributes"
| filter ContactId = "your-contact-id"
| sort @timestamp asc
------------------------------------------------------------------------------------------------------------------


------------------------------------------------------------------------------------------------------------------
-- Query 9
-- Visualize Attribute Usage Over Time
-- Purpose: Plots attribute usage frequency over time, helping identify trends or anomalies.
-- Use Case: Use the Visualization tab in CloudWatch Insights to graph results as a bar chart or line graph.
------------------------------------------------------------------------------------------------------------------
fields @timestamp
| filter ContactFlowModuleType = "SetAttributes"
| stats count() by Parameters.Key, bin(1h)
| sort @timestamp asc
------------------------------------------------------------------------------------------------------------------


------------------------------------------------------------------------------------------------------------------
-- Query 10
-- Discover Attributes Set in First 2 Seconds of Contact
------------------------------------------------------------------------------------------------------------------
fields @timestamp, ContactId, ContactFlowModuleType, Parameters.Key
| filter ContactFlowModuleType in ["SetLoggingBehavior", "SetAttributes"]
| stats min(if(ContactFlowModuleType = "SetLoggingBehavior", @timestamp, null)) as firstLoggingTime,
        count(if(ContactFlowModuleType = "SetAttributes" and @timestamp <= firstLoggingTime + 2000 and ispresent(Parameters.Key), 1, 0)) as attrCount
  by ContactId, Parameters.Key
| filter ispresent(firstLoggingTime)
| filter attrCount > 0
| fields ContactId, firstLoggingTime, Parameters.Key
| sort ContactId asc, firstLoggingTime asc
| limit 2000
------------------------------------------------------------------------------------------------------------------

-- 1. Field Selection
fields @timestamp, ContactId, ContactFlowModuleType, Parameters.Key
-- Selects the timestamp, contact ID, module type, and attribute key (for SetAttributes events).
-- Parameters.Key is null for SetLoggingBehavior events but included for later filtering.

-- 2. Filter Relevant Module Types
| filter ContactFlowModuleType in ["SetLoggingBehavior", "SetAttributes"]
-- Limits the dataset to log entries for SetLoggingBehavior
-- (to find the first logging event) and SetAttributes (to get attribute keys).

-- 3. Aggregation by ContactId
| stats min(if(ContactFlowModuleType = "SetLoggingBehavior", @timestamp, null)) as firstLoggingTime,
        collect_list(if(ContactFlowModuleType = "SetAttributes" and @timestamp <= firstLoggingTime + 2000, Parameters.Key, null)) as attributeKeys
  by ContactId
-- min(if(...)): For each ContactId, finds the earliest @timestamp where ContactFlowModuleType = "SetLoggingBehavior", storing it as firstLoggingTime.
-- collect_list(if(...)): Collects all Parameters.Key values from SetAttributes events where the timestamp is within 2 seconds (2000 milliseconds) of firstLoggingTime. Non-matching entries are set to null.
-- by ContactId: Groups results by ContactId to process each contact independently.

-- Filter Valid Results
| filter ispresent(firstLoggingTime)
| filter array_length(attributeKeys) > 0
-- Ensures only ContactId values with a SetLoggingBehavior event are included.
-- Excludes cases where no SetAttributes events occur within 2 seconds (i.e., the attributeKeys array is empty or contains only null).

-- Format Output:
| parse @timestamp "%Y-%m-%dT%H:%M:%S.%fZ" as parsedTimestamp
| fields ContactId, firstLoggingTime, array_join(filter(attributeKeys, x -> x is not null), ", ") as attributeKeysList
-- Parses @timestamp for clarity (though not strictly necessary since we’re using firstLoggingTime directly).
-- Uses array_join and filter to convert the attributeKeys array into a comma-separated string, excluding null values.
-- Outputs ContactId, firstLoggingTime, and the list of attribute keys.

-- Sort and Limit
| sort ContactId asc
| limit 1000
-- Sorts by ContactId for readability.
-- Limits output to 1000 rows to manage large datasets (adjust as needed).
