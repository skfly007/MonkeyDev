#!/bin/zsh

#多渠道打包



echo "初始化脚本执行环境"
#set -e表示一旦脚本中有命令的返回值为非0，则脚本立即退出，后续命令不再执行;
#set -o pipefail表示在管道连接的命令序列中，只要有任何一个命令返回非0值，则整个管道返回非0值，即使最后一个命令返回0.
set -e



channels_file="./channels.txt"
channel_content_file='_Info.txt'


while getopts :c: opt
do
  case "$opt" in
  c)
    channels_file=$OPTARG
    echo "渠道文件: ${channels_file}"
    ;;
  *) echo "Unknown option: $opt";;
  esac
done

for channel in $(cat $channels_file)
do
	echo "打包生成ipa文件(未签名) 渠道 $channel"
  for tmpApp in Payload/*.app
  do
#    echo ${tmpApp}
#    echo ${tmpApp}/_Info.txt
    touch ${tmpApp}/_Info.txt
	  echo $channel > ${tmpApp}/${channel_content_file}
	done
	zip -r ./out_unsigned_${channel}.ipa Payload
done

echo "渠道包打包完毕!"

