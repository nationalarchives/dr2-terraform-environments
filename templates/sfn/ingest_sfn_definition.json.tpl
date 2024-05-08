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
            "Lambda.TooManyRequestsException",
            "Lambda.Unknown"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        },
        {
          "ErrorEquals": [
            "States.ALL"
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
            "Lambda.TooManyRequestsException",
            "Lambda.Unknown"
          ],
          "IntervalSeconds": 5,
          "MaxAttempts": 15,
          "BackoffRate": 1
        },
        {
          "ErrorEquals": [
            "States.ALL"
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
        "StartAt": "Check if asset has already been ingested",
        "States": {
          "Check if asset has already been ingested": {
            "Type": "Task",
            "Resource": "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_check_preservica_for_existing_io}",
            "Retry": [
              {
                "ErrorEquals": [
                  "Lambda.ServiceException",
                  "Lambda.AWSLambdaException",
                  "Lambda.SdkClientException",
                  "Lambda.TooManyRequestsException",
                  "Lambda.Unknown"
                ],
                "IntervalSeconds": 2,
                "MaxAttempts": 6,
                "BackoffRate": 2
              },
              {
                "ErrorEquals": [
                  "States.ALL"
                ],
                "IntervalSeconds": 2,
                "MaxAttempts": 6,
                "BackoffRate": 2
              }
            ],
            "ResultPath": "$.AssetExistsResult",
            "Next": "Decide whether to continue ingesting asset or skip"
          },
          "Decide whether to continue ingesting asset or skip": {
            "Type": "Choice",
            "Choices": [
              {
                "Variable": "$.AssetExistsResult.assetExists",
                "BooleanEquals": true,
                "Next": "Skip ingesting asset"
              },
              {
                "Variable": "$.AssetExistsResult.assetExists",
                "BooleanEquals": false,
                "Next": "Create Asset OPEX"
              }
            ]
          },
          "Skip ingesting asset": {
            "Type": "Succeed"
          },
          "Create Asset OPEX": {
            "Type": "Task",
            "Resource": "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_asset_opex_creator_lambda_name}",
            "Retry": [
              {
                "ErrorEquals": [
                  "Lambda.ServiceException",
                  "Lambda.AWSLambdaException",
                  "Lambda.SdkClientException",
                  "Lambda.TooManyRequestsException",
                  "Lambda.Unknown"
                ],
                "IntervalSeconds": 2,
                "MaxAttempts": 6,
                "BackoffRate": 2
              },
              {
                "ErrorEquals": [
                  "States.ALL"
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
        },
        "contentAssets.$": "$.contentAssets"
      }
    },
    "Merge array": {
      "Type": "Pass",
      "Next": "Map over each Folder Id",
      "Parameters": {
        "allFolders.$": "$.allFolders.[*]*",
        "contentAssets.$": "$.contentAssets",
        "executionId.$": "$$.Execution.Name",
        "workflowContextName": "Ingest OPEX (Incremental)",
        "stagingPrefix.$": "States.Format('opex/{}', $$.Execution.Name)",
        "stagingBucket": "${ingest_staging_cache_bucket_name}"
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
                  "Lambda.TooManyRequestsException",
                  "Lambda.Unknown"
                ],
                "IntervalSeconds": 2,
                "MaxAttempts": 6,
                "BackoffRate": 2
              },
              {
                "ErrorEquals": [
                  "States.ALL"
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
      "ResultPath": null,
      "Next": "Create '.opex' manifest file for ingest container folder"
    },
    "Create '.opex' manifest file for ingest container folder": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_parent_folder_opex_creator_lambda_name}",
      "Parameters": {
        "executionId.$": "$$.Execution.Name",
        "batchId.$": "$$.Execution.Input.batchId",
        "stagingPrefix.$": "States.Format('opex/{}', $$.Execution.Name)",
        "stagingBucket": "${ingest_staging_cache_bucket_name}"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException",
            "Lambda.TooManyRequestsException",
            "Lambda.Unknown"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        },
        {
          "ErrorEquals": [
            "States.ALL"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "ResultPath": null,
      "Next": "Start datasync task"
    },
    "Start datasync task": {
      "Type": "Task",
      "Next": "Wait 20 Seconds",
      "Parameters": {
        "TaskArn": "${datasync_task_arn}",
        "Includes": [
          {
            "FilterType": "SIMPLE_PATTERN",
            "Value.$": "States.Format('/opex/{}', $$.Execution.Name)"
          }
        ]
      },
      "Resource": "arn:aws:states:::aws-sdk:datasync:startTaskExecution",
      "Credentials": {
        "RoleArn": "${tna_to_preservica_role_arn}"
      },
      "ResultPath": "$.datasyncExecution"
    },
    "Wait 20 Seconds": {
      "Type": "Wait",
      "Next": "DescribeTaskExecution",
      "Seconds": 20
    },
    "DescribeTaskExecution": {
      "Type": "Task",
      "Next": "Job Complete?",
      "Parameters": {
        "TaskExecutionArn.$": "$.datasyncExecution.TaskExecutionArn"
      },
      "Resource": "arn:aws:states:::aws-sdk:datasync:describeTaskExecution",
      "Credentials": {
        "RoleArn": "${tna_to_preservica_role_arn}"
      },
      "ResultSelector": {
        "TaskExecutionArn.$": "$.TaskExecutionArn",
        "Status.$": "$.Status"
      },
      "ResultPath": "$.datasyncExecution"
    },
    "Job Complete?": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.datasyncExecution.Status",
          "StringEquals": "ERROR",
          "Next": "Job Failed"
        },
        {
          "Variable": "$.datasyncExecution.Status",
          "StringEquals": "SUCCESS",
          "Next": "Start workflow"
        }
      ],
      "Default": "Wait 20 Seconds"
    },
    "Start workflow": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
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
            "Lambda.TooManyRequestsException",
            "Lambda.Unknown"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        },
        {
          "ErrorEquals": [
            "States.ALL"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "ResultPath": null,
      "Next": "Wait 5 minutes before getting status"
    },
    "Wait 5 minutes before getting status": {
      "Type": "Wait",
      "Next": "Get workflow status",
      "Seconds": 300
    },
    "Get workflow status": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_workflow_monitor_lambda_name}"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException",
            "Lambda.TooManyRequestsException",
            "Lambda.Unknown"
          ],
          "IntervalSeconds": 1,
          "MaxAttempts": 3,
          "BackoffRate": 2
        },
        {
          "ErrorEquals": [
            "States.ALL"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "ResultSelector": {
        "status.$": "$.Payload.status",
        "mappedId.$": "$.Payload.mappedId",
        "succeededAssets.$": "$.Payload.succeededAssets",
        "failedAssets.$": "$.Payload.failedAssets",
        "duplicatedAssets.$": "$.Payload.duplicatedAssets"
      },
      "ResultPath": "$.WorkflowResult",
      "Next": "Check workflow status and get Succeeded, Failed and Duplicated asset ids"
    },
    "Check workflow status and get Succeeded, Failed and Duplicated asset ids": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.WorkflowResult.status",
          "StringEquals": "Failed",
          "Next": "Job Failed"
        },
        {
          "Variable": "$.WorkflowResult.status",
          "StringEquals": "Succeeded",
          "Next": "Map over each assetId and reconcile"
        }
      ],
      "Default": "Wait 1 minute"
    },
    "Wait 1 minute": {
      "Type": "Wait",
      "Next": "Get workflow status",
      "Seconds": 60
    },
    "Job Failed": {
      "Type": "Fail",
      "Cause": "AWS Batch Job Failed",
      "Error": "'Check workflow status' task returned Failed"
    },
    "Map over each assetId and reconcile": {
      "Type": "Map",
      "ItemsPath": "$.contentAssets",
      "ItemSelector": {
        "assetId.$": "$$.Map.Item.Value",
        "batchId.$": "$$.Execution.Input.batchId",
        "executionId.$": "$.executionId"
      },
      "ItemProcessor": {
        "ProcessorConfig": {
          "Mode": "INLINE"
        },
        "StartAt": "Reconcile assetId and children",
        "States": {
          "Reconcile assetId and children": {
            "Type": "Task",
            "Resource": "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_asset_reconciler_lambda_name}",
            "Retry": [
              {
                "ErrorEquals": [
                  "Lambda.ServiceException",
                  "Lambda.AWSLambdaException",
                  "Lambda.SdkClientException",
                  "Lambda.TooManyRequestsException",
                  "Lambda.Unknown"
                ],
                "IntervalSeconds": 2,
                "MaxAttempts": 6,
                "BackoffRate": 2
              },
              {
                "ErrorEquals": [
                  "States.ALL"
                ],
                "IntervalSeconds": 2,
                "MaxAttempts": 6,
                "BackoffRate": 2
              }
            ],
            "Next": "Check if Reconciliation succeeded and post to Slack if it didn't"
          },
          "Check if Reconciliation succeeded and post to Slack if it didn't": {
            "Type": "Choice",
            "Choices": [
              {
                "Variable": "$.wasReconciled",
                "BooleanEquals": false,
                "Next": "Post failure message to Slack"
              },
              {
                "Variable": "$.wasReconciled",
                "BooleanEquals": true,
                "Next": "Do nothing"
              }
            ],
            "Default": "Throw Reconciler job error"
          },
          "Do nothing": {
            "Type": "Pass",
            "End": true
          },
          "Post failure message to Slack": {
            "Type": "Task",
            "Resource": "arn:aws:states:::events:putEvents",
            "Parameters": {
              "Entries": [
                {
                  "Detail": {
                    "slackMessage.$": "$.reason"
                  },
                  "DetailType": "DR2Message",
                  "EventBusName": "default",
                  "Source": "reconcilerLambda"
                }
              ]
            },
            "End": true
          },
          "Throw Reconciler job error": {
            "Type": "Fail",
            "Cause": "AWS Batch Job Failed",
            "Error": "'wasReconciled' value was neither 'true' nor 'false'"
          }
        }
      },
      "Next": "Get number of items in lock table that have this batchId"
    },
    "Get number of items in lock table that have this batchId": {
      "Type": "Task",
      "Parameters": {
        "TableName": "${ingest_lock_table_name}",
        "IndexName": "${ingest_lock_table_batch_id_gsi_name}",
        "KeyConditionExpression": "batchId = :lookUpId",
        "ExpressionAttributeValues": {
          ":lookUpId": {
            "S.$": "$$.Execution.Input.batchId"
          }
        }
      },
      "Resource": "arn:aws:states:::aws-sdk:dynamodb:query",
      "Next": "Check if number of items is 0"
    },
    "Check if number of items is 0": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.Count",
          "NumericEquals": 0,
          "Next": "Do nothing, as items have been removed from lock table"
        }
      ],
      "Default": "Throw error, as items haven't been removed from lock table"
    },
    "Do nothing, as items have been removed from lock table": {
      "Type": "Pass",
      "End": true
    },
    "Throw error, as items haven't been removed from lock table": {
      "Type": "Fail",
      "Cause": "Items with batchId still exist in lock table",
      "Error": "Items with batchId still exist in lock table"
    }
  }
}
