import json
import secrets

import boto3


secrets_manager = boto3.client("secretsmanager")


def quote_connection_value(value):
    return '"' + str(value).replace('"', '""') + '"'


def handler(event, _context):
    source = secrets_manager.get_secret_value(SecretId=event["source_secret_arn"])
    credentials = json.loads(source["SecretString"])

    def build_connection_string(host):
        return ";".join(
            [
                f"Host={quote_connection_value(host)}",
                f"Port={int(event['db_port'])}",
                f"Database={quote_connection_value(event['db_name'])}",
                f"Username={quote_connection_value(event['db_username'])}",
                f"Password={quote_connection_value(credentials['password'])}",
                "SSL Mode=VerifyFull",
            ]
        )

    secrets_manager.put_secret_value(
        SecretId=event["connection_arn"],
        SecretString=build_connection_string(event["db_host"]),
    )
    if event.get("reader_arn"):
        secrets_manager.put_secret_value(
            SecretId=event["reader_arn"],
            SecretString=build_connection_string(event["replica_host"]),
        )
    secrets_manager.put_secret_value(
        SecretId=event["jwt_secret_arn"],
        SecretString=secrets.token_urlsafe(64),
    )

    return {"seeded": True}