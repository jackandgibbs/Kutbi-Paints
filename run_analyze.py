import subprocess

def run_analysis():
    with open('analyze_output.txt', 'w', encoding='utf-8') as f:
        subprocess.run('dart analyze', stdout=f, stderr=subprocess.STDOUT, shell=True)

if __name__ == '__main__':
    run_analysis()
