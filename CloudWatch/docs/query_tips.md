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


