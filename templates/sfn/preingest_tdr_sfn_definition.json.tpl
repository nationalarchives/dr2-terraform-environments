{
  "Comment": "A state machine to run the preingest process for TDR transfers",
  "StartAt": "Wait",
  "States": {
    "Wait": {
      "Type": "Wait",
      "SecondsPath": "$.waitFor",
      "Next": "Invoke Package Builder Lambda"
    },
    "Invoke Package Builder Lambda": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "arn:aws:lambda:eu-west-2:${account_id}:function:${package_builder_lambda_name}"
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
      "Next": "Start Ingest Step Function",
      "ResultSelector": {
        "groupId.$": "$.Payload.groupId",
        "batchId.$": "$.Payload.batchId",
        "retryCount.$": "$.Payload.retryCount",
        "retrySfnArn.$": "$$.StateMachine.Id",
        "packageMetadata.$": "$.Payload.packageMetadata"
      }
    },
    "Start Ingest Step Function": {
      "Type": "Task",
      "Resource": "arn:aws:states:::states:startExecution",
      "Parameters": {
        "StateMachineArn": "${ingest_step_function_arn}",
        "Name.$": "$$.Execution.Name",
        "Input.$": "$"
      },
      "End": true
    }
  }
}