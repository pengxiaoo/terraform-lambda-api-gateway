import os
import logging
import json
from pymongo import MongoClient, ReadPreference

logger = logging.getLogger()
logger.setLevel(logging.INFO)
user = os.getenv('MONGO_USER')
pwd = os.getenv('MONGO_PWD')
db_name = os.getenv('MONGO_DATABASE')
col_actions_name = os.getenv('MONGO_COL_ACTIONS')
col_operations_name = os.getenv('MONGO_COL_OPERATIONS')
mongo_host_and_params = os.getenv('MONGO_HOST_AND_PARAMS')


def lambda_handler(event, context):
    logger.info(f'received incoming event:{json.dumps(event)}')
    method = event['requestContext']['httpMethod']
    path = event['requestContext']['path']
    params = event['queryStringParameters']
    logger.info(f'method:{method}, path:{path}, params:{params}')
    client = MongoClient(f'mongodb://{user}:{pwd}@{mongo_host_and_params}')

    try:
        if path == '/v1/actions':
            db = client.get_database(db_name, read_preference=ReadPreference.SECONDARY)
            col = db.get_collection(col_actions_name)
            cursor = col.find({}, {"_id": 0}).sort([("timestamp", -1)])
            return build_response(200, body={
                'actions': list(cursor)
            })
        elif path == '/v1/operations':
            uuid = params['uuid']
            db = client.get_database(db_name, read_preference=ReadPreference.SECONDARY)
            col = db.get_collection(col_operations_name)
            cursor = col.find({"uuid": uuid}, {"_id": 0}).sort([("timestamp", -1)])
            return build_response(200, body={
                'operations': list(cursor)
            })
        else:
            return build_response(404, 'invalid url, please check your input!')
    except Exception as e:
        return build_response(404, f'error happens! {e}')
    else:
        pass


def build_response(statusCode, body):
    response = {
        'statusCode': statusCode,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        }
    }
    if body is not None:
        response['body'] = json.dumps(body)
    return response
