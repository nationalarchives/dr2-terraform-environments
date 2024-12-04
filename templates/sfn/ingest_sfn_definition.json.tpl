{
  "Comment": "${step_function_name}: A State machine to ingest DR2 BagIt-like packages into Preservica.",
  "StartAt": "Validate input",
  "States": {
    "Validate input": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_validate_generic_ingest_inputs_lambda_name}",
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
      "Next": "Get metadata and update Files table"
    },
    "Get metadata and update Files table": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_mapper_lambda_name}",
      "Parameters": {
        "batchId.$": "$.batchId",
        "metadataPackage.$": "$.metadataPackage",
        "executionName.$": "$$.Execution.Name"
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
      "Next": "Map over each Asset Id"
    },
    "Map over each Asset Id": {
      "Type": "Map",
      "Label": "MapOverEachAssetId",
      "ItemsPath": "$.contentAssets",
      "ItemSelector": {
        "id.$": "$$.Map.Item.Value",
        "batchId.$": "$$.Execution.Input.batchId",
        "executionName.$": "$$.Execution.Name"
      },
      "ItemReader": {
        "Resource": "arn:aws:states:::s3:getObject",
        "ReaderConfig": {
          "InputType": "JSON"
        },
        "Parameters": {
          "Bucket.$": "$.assets.bucket",
          "Key.$": "$.assets.key"
        }
      },
      "ItemProcessor": {
        "ProcessorConfig": {
          "Mode": "DISTRIBUTED",
          "ExecutionType": "STANDARD"
        },
        "StartAt": "Check if asset has already been ingested",
        "States": {
          "Check if asset has already been ingested": {
            "Type": "Task",
            "Resource": "arn:aws:lambda:eu-west-2:${account_id}:function:${ingest_find_existing_asset_name_lambda_name}",
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
            "Next": "Create Asset OPEX"
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
      "Next": "Map over each Folder Id",
      "ResultPath": null,
      "ItemBatcher": {
        "MaxItemsPerBatch": 20
      },
      "MaxConcurrency": 10
    },
    "Map over each Folder Id": {
      "Type": "Map",
      "Label": "MapOverEachFolderId",
      "ItemReader": {
        "Resource": "arn:aws:states:::s3:getObject",
        "ReaderConfig": {
          "InputType": "JSON"
        },
        "Parameters": {
          "Bucket.$": "$.folders.bucket",
          "Key.$": "$.folders.key"
        }
      },
      "ItemSelector": {
        "id.$": "$$.Map.Item.Value",
        "batchId.$": "$$.Execution.Input.batchId",
        "executionName.$": "$$.Execution.Name"
      },
      "ItemProcessor": {
        "ProcessorConfig": {
          "Mode": "DISTRIBUTED",
          "ExecutionType": "STANDARD"
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
      "Next": "Start 'Run Workflow' Step Function"
    },
    "Start 'Run Workflow' Step Function": {
      "Type": "Task",
      "Resource": "arn:aws:states:::states:startExecution.sync:2",
      "Parameters": {
        "StateMachineArn": "arn:aws:states:eu-west-2:${account_id}:stateMachine:${ingest_run_workflow_sfn_name}",
        "Name.$": "$$.Execution.Name",
        "Input.$": "States.JsonMerge($, States.StringToJson(States.Format('\\{\"{}\":\"{}\"\\}', 'AWS_STEP_FUNCTIONS_STARTED_BY_EXECUTION_ID', $$.Execution.Id)), false)"
      },
      "OutputPath": "$.Output",
      "Next": "Map over each assetId and reconcile"
    },
    "Map over each assetId and reconcile": {
      "Type": "Map",
      "Label": "MapOverEachAssetIdAndReconcile",
      "ItemReader": {
        "Resource": "arn:aws:states:::s3:getObject",
        "ReaderConfig": {
          "InputType": "JSON"
        },
        "Parameters": {
          "Bucket.$": "$.assets.bucket",
          "Key.$": "$.assets.key"
        }
      },
      "MaxConcurrency": 25,
      "ItemSelector": {
        "assetId.$": "$$.Map.Item.Value",
        "batchId.$": "$$.Execution.Input.batchId",
        "executionId.$": "$$.Execution.Name"
      },
      "ItemProcessor": {
        "ProcessorConfig": {
          "Mode": "DISTRIBUTED",
          "ExecutionType": "STANDARD"
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
                "Next": "Update ingested_PS attribute in Files table"
              }
            ],
            "Default": "Throw Reconciler job error"
          },
          "Update ingested_PS attribute in Files table": {
            "Type": "Task",
            "Resource": "arn:aws:states:::dynamodb:updateItem",
            "Parameters": {
              "TableName": "${ingest_files_table_name}",
              "Key": {
                "id": {
                  "S.$": "$.assetId"
                },
                "batchId": {
                  "S.$": "$$.Execution.Input.batchId"
                }
              },
              "UpdateExpression": "SET ingested_PS = :ingestedPSValue",
              "ExpressionAttributeValues": {
                ":ingestedPSValue": {
                  "S": "true"
                }
              }
            },
            "ResultPath": null,
            "Next": "Delete asset item from lock table"
          },
          "Delete asset item from lock table": {
            "Type": "Task",
            "Resource": "arn:aws:states:::dynamodb:deleteItem",
            "Parameters": {
              "TableName": "${ingest_lock_table_name}",
              "Key": {
                "${ingest_lock_table_hash_key}": {
                  "S.$": "$.assetId"
                }
              }
            },
            "ResultPath": null,
            "End": true
          },
          "Post failure message to Slack": {
            "Type": "Task",
            "Resource": "arn:aws:states:::events:putEvents",
            "Parameters": {
              "Entries": [
                {
                  "Detail": {
                    "slackMessage.$": "States.Format(':alert-noflash-slow: Reconciliation failed for asset {}. See the state output for the result key.', $.assetId)"
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
      "Next": "Get number of items in lock table that have this groupId",
      "ResultWriter": {
        "Resource": "arn:aws:states:::s3:putObject",
        "Parameters": {
          "Bucket.$": "$.assets.bucket",
          "Prefix": "reconcilerOutput"
        }
      }
    },
    "Get number of items in lock table that have this groupId": {
      "Type": "Task",
      "Parameters": {
        "TableName": "${ingest_lock_table_name}",
        "IndexName": "${ingest_lock_table_group_id_gsi_name}",
        "KeyConditionExpression": "groupId = :lookUpId",
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
      "Default": "Check if retryCount is less than 2"
    },
    "Do nothing, as items have been removed from lock table": {
      "Type": "Pass",
      "End": true
    },
    "Check if retryCount is less than 2": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$$.Execution.Input.retryCount",
          "NumericLessThan": 2,
          "Next": "Add 1 to retry count"
        }
      ],
      "Default": "Throw error, as items haven't been removed from lock table"
    },
    "Add 1 to retry count": {
      "Type": "Pass",
      "Parameters": {
        "retryCountPlus1.$": "States.MathAdd($$.Execution.Input.retryCount, 1)"
      },
      "Next": "Concatenate groupId and retryCount + 1"
    },
    "Concatenate groupId and retryCount + 1": {
      "Type": "Pass",
      "Parameters": {
        "newRetryCount.$": "$.retryCountPlus1",
        "newBatchId.$": "States.Format('{}_{}', $$.Execution.Input.groupId, $.retryCountPlus1)"
      },
      "Next": "Retry pre-ingest step function"
    },
    "Retry pre-ingest step function": {
      "Type": "Task",
      "Resource": "arn:aws:states:::states:startExecution",
      "Parameters": {
        "StateMachineArn.$": "$$.Execution.Input.retrySfnArn",
        "Name.$": "$.newBatchId",
        "Input": {
          "groupId.$": "$$.Execution.Input.groupId",
          "batchId.$": "$.newBatchId",
          "waitFor": 0,
          "retryCount.$": "$.newRetryCount"
        }
      },
      "End": true
    },
    "Throw error, as items haven't been removed from lock table": {
      "Type": "Fail",
      "Cause": "Items with groupId still exist in lock table",
      "Error": "Items with groupId still exist in lock table"
    }
  }
}