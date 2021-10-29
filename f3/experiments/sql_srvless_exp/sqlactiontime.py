import sqlite3
import time


def get_response(do_query, show_result):

    user_code_start = time.time()

    if show_result:
        response = dict()
        response['source'] = 'openwhisk web action'
        response['user_code_start'] = ('%.6f' % user_code_start)
    else:
        response = "source:openwhisk_web_action\n"
        response += f"user_code_start:{'%.6f' % user_code_start}\n"

    if do_query:
        # want query time
        conn = sqlite3.connect('/var/data/TPC-H.db')

        fd = open('/var/data/queries.sql', 'r')
        sqlFile = fd.read()
        fd.close()

        # split SQL commands on ;
        sqlCommands = sqlFile.split(';')

        # execute all commands from input file
        query = 1
        results = dict()
        start_time = int(time.time())
        for cmd in sqlCommands[:-1]:
            try:
                cursor = conn.execute(cmd)
                result = cursor.fetchall()
                query_str = 'query' + str(query)
                query = query + 1
                # don't actually care about reading all of the result
                results[query_str] = result[0]
            except (sqlite3.OperationalError):
                print("Command skipped: ", cmd)
        end_time = int(time.time())
        if show_result:
            response['query_time'] = str(end_time-start_time)
            response['results'] = results
        else:
            response += f"query_time:{'%.6f' % (end_time-start_time)}\n"
    return {'body': response}


def main(args):
    if args["__ow_path"] == "/endtoend":
        do_query = False
        show_result = False
    elif args["__ow_path"] == "/time":
        do_query = True
        show_result = False
    else:
        do_query = True
        show_result = True

    return get_response(do_query, show_result)
