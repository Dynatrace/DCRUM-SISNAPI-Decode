# SISNAPI script for DC RUM

The script enables you to monitor performance of SISNAPI. By default, it recognizes Siebel command (parameter SWECmd), a method name if executed (parameter SWEMethod), as well as the business context in which an operation is executed.This allows you to monitor qualitative and quantitative parameters of executed operations, pinpoint the fault domain and determine the root cause of slow operations.
Additionally, the analysis module parses the responses, through which it is capable of reporting Siebel errors. To achieve that, you need to configure the Simple Parser Availability reporting and enable reporting of Operation Attributes 4 and 5 for Failures (application) at the Software Service level.

Detailed description is available [here](https://community.dynatrace.com/community/display/PUBDCRUM/Universal+Decode+Implementations#UniversalDecodeImplementations-SISNAPI).

## What is Dynatrace DC RUM?

[Data Center Real User Monitoring (DC RUM)](http://www.dynatrace.com/en/data-center-rum/) is an effective, non-intrusive choice for monitoring business applications that are accessed by employees, partners, and customers outside the corporate enterprise or from the corporate network (intranet or extranet).

## Which DC RUM versions are compatible with the SISNAPI script?

12.3 or later, Classic AMD.

## Where can I find the newest version of the SISNAPI script?

See the [Universal Decode Implementations](https://community.dynatrace.com/community/display/PUBDCRUM/Bespoke+application+monitoring+with+the+Universal+Decode#BespokeapplicationmonitoringwiththeUniversalDecode-SISNAPI)
page.

## How can I run the script from sources?

See [Using and Maintaining Software Services Definitions Based on Universal Decode](https://community.dynatrace.com/community/display/DCRUM124/Using+and+Maintaining+Software+Services+Definitions+Based+on+Universal+Decode).

## Problems? Questions? Suggestions?

This offering is [Dynatrace Community Supported](https://community.dynatrace.com/community/display/DL/Support+Levels#SupportLevels-Communitysupported/NotSupportedbyDynatrace(providedbyacommunitymember)).
Feel free to share any problems, questions, and suggestions with your peers on the Dynatrace Community
[Data Center RUM forum](https://answers.dynatrace.com/spaces/160/index.html).

## License

Licensed under the BSD License. See the [LICENSE](LICENSE) file for details.
