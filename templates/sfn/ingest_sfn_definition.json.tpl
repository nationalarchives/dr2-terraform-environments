{
  "Comment": "${step_function_name}: A State machine to ingest DR2 BagIt-like packages into Preservica.",
  "StartAt": "Map metadata",
  "States": {
    "Map metadata": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_mapper_lambda_name}",
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
      "Resource": "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_upsert_archive_folders_lambda_name}",
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException",
            "Lambda.TooManyRequestsException"
          ],
          "IntervalSeconds": 5,
          "MaxAttempts": 15,
          "BackoffRate": 1
        }
      ],
      "Next": "Map over each Asset Id",
      "ResultPath": null
    },
    "Map over each Asset Id": {
      "Type": "Map",
      "ItemsPath": "$.contentAssets",
      "ItemSelector": {
        "id.$": "$$.Map.Item.Value",
        "batchId.$": "$$.Execution.Input.batchId",
        "executionName.$": "$$.Execution.Name",
        "sourceBucket.$": "$.s3Bucket"
      },
      "ItemProcessor": {
        "ProcessorConfig": {
          "Mode": "INLINE"
        },
        "StartAt": "Create Asset OPEX",
        "States": {
          "Create Asset OPEX": {
            "Type": "Task",
            "Resource": "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_asset_opex_creator_lambda_name}",
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
      "Next": "Convert array to object",
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
      "ItemsPath": "$.allFolders",
      "ItemSelector": {
        "id.$": "$$.Map.Item.Value",
        "batchId.$": "$$.Execution.Input.batchId",
        "executionName.$": "$$.Execution.Name"
      },
      "ItemProcessor": {
        "ProcessorConfig": {
          "Mode": "INLINE"
        },
        "StartAt": "Create Folder OPEX",
        "States": {
          "Create Folder OPEX": {
            "Type": "Task",
            "Resource": "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_folder_opex_creator_lambda_name}",
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
      "Next": "Create '.opex' manifest file for ingest container folder",
      "ResultSelector": {
        "executionId.$": "$$.Execution.Name",
        "stagingPrefix.$": "States.Format('opex/{}', $$.Execution.Name)",
        "stagingBucket": "${ingest_staging_cache_bucket_name}"
      }
    },
    "Create '.opex' manifest file for ingest container folder": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_parent_folder_opex_creator_lambda_name}",
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
      "ResultPath": null,
      "Next": "Staging cache S3 object keys"
    },
    "Staging cache S3 object keys": {
      "Type": "Map",
      "ItemProcessor": {
        "ProcessorConfig": {
          "Mode": "DISTRIBUTED",
          "ExecutionType": "STANDARD"
        },
        "StartAt": "Copy to Preservica bucket",
        "States": {
          "Copy to Preservica bucket": {
            "Type": "Task",
            "Resource": "arn:aws:states:::lambda:invoke",
            "Parameters": {
              "Payload.$": "$",
              "FunctionName": "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_s3_copy_lambda_name}"
            },
            "Retry": [
              {
                "ErrorEquals": [
                  "Lambda.ServiceException",
                  "Lambda.AWSLambdaException",
                  "Lambda.SdkClientException",
                  "Lambda.TooManyRequestsException"
                ],
                "IntervalSeconds": 1,
                "MaxAttempts": 3,
                "BackoffRate": 2
              }
            ],
            "End": true
          }
        }
      },
      "ItemReader": {
        "Resource": "arn:aws:states:::s3:listObjectsV2",
        "Parameters": {
          "Bucket.$": "$.stagingBucket",
          "Prefix.$": "$.stagingPrefix"
        }
      },
      "MaxConcurrency": 1000,
      "Label": "StagingCacheS3ObjectKeys",
      "Next": "Start workflow",
      "ItemBatcher": {
        "MaxItemsPerBatch": 10,
        "BatchInput": {
          "tnaBucket": "${ingest_staging_cache_bucket_name}",
          "preservicaBucket": "${preservica_bucket_name}"
        }
      },
      "ResultSelector": {
        "workflowContextName": "Ingest OPEX (Incremental)",
        "executionId.$": "$$.Execution.Name"
      }
    },
    "Start workflow": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "FunctionName": "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_start_workflow_lambda_name}",
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
      "End": true
    }
  }
}
