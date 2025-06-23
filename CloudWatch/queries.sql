
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
| filter ContactFlowModuleType = "SetAttributes"
| stats count() as attrCount by ContactId, Parameters.Key
| filter attrCount > 0
| fields ContactId, Parameters.Key
| sort ContactId asc
| limit 1000
------------------------------------------------------------------------------------------------------------------

-- 1. Field Selection
fields @timestamp, ContactId, ContactFlowModuleType, Parameters.Key
-- Selects the timestamp, contact ID, module type, and attribute key (for SetAttributes events).
-- Parameters.Key is null for SetLoggingBehavior events but included for later filtering.

-- 2. Filter Relevant Module Types
| filter ContactFlowModuleType in ["SetLoggingBehavior", "SetAttributes"]
-- Purpose: Restricts the dataset to log entries where ContactFlowModuleType is exactly "SetAttributes".

-- 3. Count contact id with each unique attribute
| stats count() as attrCount by ContactId, Parameters.Key
-- Purpose: Aggregates the filtered data by grouping it by ContactId and Parameters.Key, counting how many times each combination occurs.
-- Details:
-- count(): Counts the number of log entries for each unique ContactId and Parameters.Key pair.
-- as attrCount: Names the count column attrCount for clarity.
-- by ContactId, Parameters.Key: Groups the results so each row represents a unique combination of ContactId and attribute key, with the count of how often that key was set for that contact.
-- Example:
-- If ContactId = abc123 has two SetAttributes events, one setting Parameters.Key = customerType and another setting Parameters.Key = greetingPlayed, the output would include:
-- ContactId = abc123, Parameters.Key = customerType, attrCount = 1
-- ContactId = abc123, Parameters.Key = greetingPlayed, attrCount = 1
-- If customerType was set twice for abc123, you’d see attrCount = 2 for that key.
-- Why This Matters: This line summarizes how frequently each attribute key is set per contact, preparing the data for further filtering and output.


-- 4.
| filter attrCount > 0
-- Purpose: Excludes rows where the count (attrCount) is zero, ensuring only valid attribute keys are included.

-- 5.
| fields ContactId, Parameters.Key
-- Purpose: Selects only the ContactId and Parameters.Key fields for the final output, discarding other fields like attrCount.

-- Sort and Limit
| sort ContactId asc
| limit 1000
