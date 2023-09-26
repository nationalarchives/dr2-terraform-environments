{
  "Comment": "${step_function_name}: A State machine to ingest DR2 BagIt-like packages into Preservica.",
  "StartAt": "Map metadata",
  "States": {
    "Map metadata": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_mapper_lambda_name}"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException",
            "Lambda.TooManyRequestsException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "Next": "Create or update folders in Preservica"
    },
    "Create or update folders in Preservica": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_upsert_archives_folder_lambda_name}",
        "Payload.$": "$"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException",
            "Lambda.TooManyRequestsException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "Next": "Map over each Asset Id",
      "ResultPath": null
    },
    "Map over each Asset Id": {
      "Type": "Map",
      "ItemProcessor": {
        "ProcessorConfig": {
          "Mode": "INLINE"
        },
        "StartAt": "Create Asset OPEX",
        "States": {
          "Create Asset OPEX": {
            "Type": "Task",
            "Resource": "arn:aws:states:::lambda:invoke",
            "OutputPath": "$.Payload",
            "Parameters": {
              "Payload.$": "$",
              "FunctionName": "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_asset_opex_creator_lambda_name}"
            },
            "Retry": [
              {
                "ErrorEquals": [
                  "Lambda.ServiceException",
                  "Lambda.AWSLambdaException",
                  "Lambda.SdkClientException",
                  "Lambda.TooManyRequestsException"
                ],
                "IntervalSeconds": 2,
                "MaxAttempts": 6,
                "BackoffRate": 2
              }
            ],
            "End": true
          }
        }
      },
      "ItemSelector": {
        "id.$": "$$.Map.Item.Value",
        "batchId.$": "$$.Execution.Input.batchId",
        "executionName.$": "$$.Execution.Name",
        "sourceBucket.$": "$.s3Bucket"
      },
      "Next": "Convert array to object",
      "ItemsPath": "$.contentAssets",
      "ResultPath": null
    },
    "Convert array to object": {
      "Type": "Pass",
      "Next": "Merge array",
      "Parameters": {
        "allFolders": {
          "archiveHierarchyFolders.$": "$.archiveHierarchyFolders",
          "contentFolders.$": "$.contentFolders"
        }
      }
    },
    "Merge array": {
      "Type": "Pass",
      "Next": "Map over each Folder Id",
      "Parameters": {
        "allFolders.$": "$.allFolders.[*]*"
      }
    },
    "Map over each Folder Id": {
      "Type": "Map",
      "ItemProcessor": {
        "ProcessorConfig": {
          "Mode": "INLINE"
        },
        "StartAt": "Create Folder OPEX",
        "States": {
          "Create Folder OPEX": {
            "Type": "Task",
            "Resource": "arn:aws:states:::lambda:invoke",
            "OutputPath": "$.Payload",
            "Parameters": {
              "Payload.$": "$",
              "FunctionName": "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_folder_opex_creator_lambda_name}"
            },
            "Retry": [
              {
                "ErrorEquals": [
                  "Lambda.ServiceException",
                  "Lambda.AWSLambdaException",
                  "Lambda.SdkClientException",
                  "Lambda.TooManyRequestsException"
                ],
                "IntervalSeconds": 2,
                "MaxAttempts": 6,
                "BackoffRate": 2
              }
            ],
            "End": true
          }
        }
      },
      "End": true,
      "ItemsPath": "$.allFolders",
      "ItemSelector": {
        "id.$": "$$.Map.Item.Value",
        "batchId.$": "$$.Execution.Input.batchId",
        "executionName.$": "$$.Execution.Name"
      }
    }
  }
}