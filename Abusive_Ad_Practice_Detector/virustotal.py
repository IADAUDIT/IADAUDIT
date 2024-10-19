import vt
import json
import os
import time
import re
from concurrent.futures import ThreadPoolExecutor
import requests
# 扫描URL并获取结果的同步函数

def get_proxy(headers):
    #proxy_url可通过多米HTTP代理网站购买后生成代理api链接，每次请求api链接都是新的ip
    proxy_url = 'http://api.dmdaili.com/dmgetip.asp?apikey=b5432355&pwd=45eccfb456436d3037076070bbf98bc9&getnum=1&httptype=1&geshi=1&fenge=1&fengefu=&operate=all'
    aaa=requests.get(proxy_url, headers=headers).text
    proxy_host = aaa.splitlines()[0]
    print('代理IP为：'+proxy_host)
    #proxy_host='117.35.254.105:22001'
    #proxy_host='192.168.0.134:1080'
    proxy = {
        'http': 'http://'+proxy_host,
        'https': 'http://'+proxy_host
    }
    return proxy_host

def set_proxy(proxy_host):
    print(proxy_host)
    os.environ['http_proxy'] = f'http://{proxy_host}'
    os.environ['https_proxy'] = f'http://{proxy_host}'
    print(f"系统代理设置为: {os.environ['http_proxy']}")

def custom_serializer(obj):
    if isinstance(obj, vt.object.Object):  # 处理 VirusTotal API 返回的自定义对象
        return obj.to_dict()
    else:
        return str(obj)

def scan_url_and_get_result(client, url, output_dir, index):
    try:
        output_file = os.path.join(output_dir, f"{index}.json")
        # 执行 URL 扫描
        analysis = client.scan_url(url)
        # 等待分析结果完成
        analysis = client.get_object(f"/analyses/{analysis.id}")

        # 等待结果状态变为 'completed'
        while analysis.status != 'completed':
            analysis = client.get_object(f"/analyses/{analysis.id}")

        # 将结果保存到单独的文件
        result = {url: analysis.to_dict()}

        # 将结果保存为JSON格式到txt文件
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(result, f, ensure_ascii=False, indent=4, default=custom_serializer)

        print(f"已保存结果到: {output_file}")
        return result
    except Exception as e:
        print(f"Error scanning {url}: {e}")
        return {url: f"Error: {e}"}

# 处理所有URL的同步函数
def scan_all_urls(api_key, urls, output_dir,start_index):
    with vt.Client(api_key) as client:
        # 遍历所有URL并启动扫描任务，按顺序命名文件
        for index in range(start_index, len(urls)):
            url = urls[index]
            output_file = os.path.join(output_dir, f"{index + 1}.json")  # +1 以保持文件名从 1 开始
            if os.path.exists(output_file):
                print(f"{output_file} exists")
                continue
            scan_url_and_get_result(client, url, output_dir, index + 1)
            time.sleep(15)

# 主函数，加载URL并启动同步任务
def main():
    headers = {
        "User-Agent": 'Mozilla/5.0'
    }
    proxy = get_proxy(headers)
    set_proxy(proxy)
    # your virustotal api keys
    api_keys = [
        'xxxxxxx',
        'xxxxxxx',
        'xxxxxxx',
        'xxxxxxx',
        'xxxxxxx',
        'xxxxxxx',
        'xxxxxxx',
        'xxxxxxx',
        'xxxxxxx',
    ]
    url_file = r"xxxxx"  # 存放1000个URL的文件
    output_dir = r'xxxxxx'  # 保存结果的目录

    # 如果目录不存在，则创建
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    # 读取URL文件
    with open(url_file, 'r') as f:
        urls = [line.strip() for line in f.readlines()]
    start_indices = [i * 100 for i in range(len(api_keys))]

    def scan_with_api_key(api_key, start_index):
        # 从指定索引开始遍历 URLs
        scan_all_urls(api_key, urls, output_dir,start_index)

    with ThreadPoolExecutor(max_workers=10) as executor:
        # Assign one API key per thread
        futures = [executor.submit(scan_with_api_key, api_key, start_index)
                   for api_key, start_index in zip(api_keys, start_indices)]
        for future in futures:
            try:
                result = future.result()  # This will block until the thread completes
            except Exception as e:
                print(f"An error occurred: {e}")




if __name__ == "__main__":
    main()
