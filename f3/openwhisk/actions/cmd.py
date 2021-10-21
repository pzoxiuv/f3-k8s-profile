import socket
import shlex
import subprocess
import json
import sys
import os

INTERCEPT_PATH = '/mnt/intercept/intercept.so'
MAX_DEPTH = 4

def main(d):
    if 'command' in d:
        cmd = d['command']
    else:
        print(json.dumps(d))
        return d

    print(f'Running {cmd}')
    #print(f'ENV: {os.environ}')
    #proc = subprocess.run(shlex.split(cmd), stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    try:
        env = os.environ
        if 'env' in d:
            for e in d['env'].split():
                if '=' in e:
                    k, v = e.split('=')
                    env[k] = v

        metadata = {'params': d, 'hostname': socket.gethostname()}
        if '__OW_ACTIVATION_ID' in env:
            metadata['activationID'] = env['__OW_ACTIVATION_ID']

        if 'PATH' not in env:
            print('Why is PATH not here???')
            env['PATH'] = '/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'

        #if '__F3_DEPTH' not in env:
        if 'f3Depth' in d:
            env['__F3_DEPTH'] = d['f3Depth']
        elif '__F3_DEPTH' not in env:
            env['__F3_DEPTH'] = str(0)
        env['__F3_DEPTH'] = str(int(env['__F3_DEPTH']) + 1)
        if int(env['__F3_DEPTH']) > MAX_DEPTH:
            print(f'ERROR call depth exceeds max depth {env["__F3_DEPTH"]} > {MAX_DEPTH}')
            return {}

        if 'cwd' in d:
            cwd = d['cwd']
        else:
            cwd = os.getcwd()

        env['__F3_PYTHON_STARTED'] = "yes"
        #env['LD_PRELOAD'] = INTERCEPT_PATH
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, env=env, cwd=cwd)
        #del env['LD_PRELOAD']
        del env['__F3_PYTHON_STARTED']

        print(f'Done, got stdout: {proc.stdout}\nstderr: {proc.stderr}\n')
        #print({'stdout': proc.stdout.decode('ascii'), 'stderr': proc.stderr.decode('ascii')})
        #return d
        #return {'stdout': proc.stdout, 'stderr': proc.stderr}
        #return {'stdout': proc.stdout.decode('ascii'), 'stderr': proc.stderr.decode('ascii')}
        return {'metadata': metadata, 'stdout': proc.stdout.decode('utf-8'), 'stderr': proc.stderr.decode('utf-8')}
    except Exception as e:
        print(e)
        return {'exception': e}

if __name__ == '__main__':
    print(main(json.loads(sys.argv[1])))
