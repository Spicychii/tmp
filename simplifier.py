def save_first_n_lines(input_file, output_file, n):
    with open(input_file, 'r') as f_input:
        with open(output_file, 'w') as f_output:
            for i, line in enumerate(f_input):
                f_output.write(line)
                if i == n - 1:
                    break
import sys
input_file = 'ERR194158_1.fastq'  # 输入的 Fastq 文件名
output_file = 'ERR194158_1_r.fastq'  # 输出的文件名
n_lines = int(sys.argv[3])#10000000  # 要读取的行数
#print(sys.argv[1],sys.argv[2])
save_first_n_lines(sys.argv[1],sys.argv[2], n_lines)