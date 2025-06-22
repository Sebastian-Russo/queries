# Tips for Querying Contact Attributes in CloudWatch Insights
- Enable Logging:
    - Ensure contact flow logging is enabled in your Amazon Connect instance (Set logging behavior block in flows) to capture attribute data in CloudWatch.
- Log Group:
    - Queries should target the log group /aws/connect/<instance-name>.
- Time Range:
    - Always set an appropriate time range in CloudWatch Insights (e.g., last 24 hours, 7 days) to avoid scanning excessive data.
- System Attributes:
    - To find system attributes, check contact event logs or refer to the Amazon Connect documentation for a list (e.g., $.CustomerEndpoint.Address, $.Queue.Name).
- External Attributes:
    - Attributes from Lex or Lambda may use specific JSONPath references (e.g., $.Lex.IntentName, $.External.AttributeKey).
- Limitations:
    - Flow attributes (temporary, flow-scoped) appear in CloudWatch logs if logging is enabled but aren’t persisted in contact records or accessible via APIs.


When a contact flow uses the Set contact attributes block, it generates log entries in CloudWatch that follow a specific JSON structure.
Understanding this structure is key to writing effective CloudWatch Logs Insights queries to extract and analyze contact attributes.

Set contact attributes block (corresponding to ContactFlowModuleType = "SetAttributes")
generates log entries in the CloudWatch log group /aws/connect/<instance-name>.
These log entries are JSON objects with a specific structure that includes details about
the contact, the flow, and the attributes being set.

Here is the expected object structure for a log entry when the SetAttributes module is executed:

{
  "AWSContactTraceRecord": {
    "ContactId": "<unique-contact-id>",
    "ContactFlowName": "<name-of-contact-flow>",
    "ContactFlowModuleType": "SetAttributes",
    "Timestamp": "<ISO-timestamp>",
    "Parameters": {
      "Key": "<attribute-key>",
      "Value": "<attribute-value>"
    },
    "Identifier": "<unique-identifier-for-action>",
    "InstanceARN": "<arn-of-connect-instance>",
    "EventName": "CONTACT_DATA_UPDATED",
    ...
  },
  "@timestamp": "<cloudwatch-timestamp>",
  "@message": "<raw-json-log-entry>",
  ...
}