import os
import shutil
from typing import List
import base64
import requests
import json
from openai import OpenAI
import httpx
import concurrent.futures



def ask_gpt4_content(content):
    client = OpenAI(
        base_url="https://api.xty.app/v1",
        # your openai api key
        api_key="xxxx",
        http_client=httpx.Client(
            base_url="https://api.xty.app/v1",
            follow_redirects=True,
        ),
    )

    completion = client.chat.completions.create(
        # model="claude-3-5-sonnet-20240620",
        model="gpt-4",
        # model="gpt-4-vision-preview",
        messages=[
            {"role": "user", "content": content},
        ],
        max_tokens=1000
    )
    print(completion.choices[0].message.content)
    return completion.choices[0].message.content

def encode_image_to_base64(image_path):
    with open(image_path, "rb") as image_file:
        encoded_string = base64.b64encode(image_file.read()).decode('utf-8')
    return encoded_string

def generate_prompt(imagepath):
    with open(r"./prompt.txt",'r',encoding='utf-8') as f:
        data = f.read()
    content = [
        {
            "type": "text",
            # "description":"background",
            "text": data
        },
        {
            "type": "text",
            # "description": "example",
            "text": "Here are some examples for reference:"
        }
    ]
    image1 = encode_image_to_base64(r"./1.png")
    content.append({
        "type": "image_url",
        # "description": "example 1",
        "image_url": {
             "url": f"data:image/png;base64,image1"}
    })
    content.append({
        "type": "text",
        # "description": "answer for example 1",
        "text": "1.No. It contains the word \"AD\" to explain it's an advertisement. \n"
                  "2.No. It doesn't contains false prizes or fake system notifications.\n "
                  "3.No. The advertisement features a cross symbol in the top-left corner for closing the image."
    })

    image2 = encode_image_to_base64(r"./2.png")
    content.append({
        "type": "image_url",
        # "description": "example 2",
        "image_url": {
            "url": f"data:image/png;base64,image2"}
    })
    content.append({
        "type": "text",
        # "description": "answer for example 2",
        "text": "1.Yes. It doesn't clearly identify itself as an ad with words like '广告' or 'AD'. \n"
                  "2.No. It doesn't contains false prizes or fake system notifications.\n "
                  "3.No. There is a cross symbol in the advertisement for closing the image."
    })

    image3 = encode_image_to_base64(r"./3.png")
    content.append({
        "type": "image_url",
        # "description": "example 3",
        "image_url": {
            "url": f"data:image/png;base64,image3"}
    })
    content.append({
        "type": "text",
        # "description": "answer for example 3",
        "text": "1.No. It contains the word \"广告\" to explain it's an advertisement. \n"
                  "2.Yes. It contains false prizes to deceive users into clicking.\n "
                  "3.No. There is a \"跳过\" button in the top-left corner of the advertisement to close it."
    })

    image4 = encode_image_to_base64(r"./4.png")
    content.append({
        "type": "image_url",
        # "description": "example 4",
        "image_url": {
            "url": f"data:image/png;base64,image4"}
    })
    content.append({
        "type": "text",
        # "description": "answer for example 4",
        "text": "1.No. It contains the word \"Advertisement\" to explain it's an advertisement and also has a Google Ads identifier in the top right corner in Ad \n"
                  "2.Yes. It not only contains a fake system notification to deceive users into clicking, but also features a fake close button that misleads users into clicking on the advertisement.\n "
                  "3.Yes. Even though there is an 'x' in the image, its position is part of the ad content, not a functional close button."
    })

    image5 = encode_image_to_base64(imagepath)
    content.append({
        "type": "image_url",
        # "description": "example 5",
        "image_url": {
            "url": f"data:image/png;base64,image5"}
    })
    # content += "\n. Please provide your answer to the question image."

    return content


def process_image(imagefile,outputfile):
    content = generate_prompt(imagefile)
    print(len(content))
    with open(outputfile, 'w', encoding='utf-8') as f:
        json.dump(content, f, ensure_ascii=False, indent=4)
    # result = ask_gpt4_content(content)
    # with open(outputfile, 'w', encoding="utf-8") as f:
    #     f.write(result)

if __name__ == '__main__':
    # ad image path
    directory = r"xxxx"
    # your output file path
    outputpath = r"xxxxx"
    futures = []
    count = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=20) as executor:
        for root, dirs, files in os.walk(directory):
            for file in files:
                if file.lower().endswith('.png'):
                    imagefile = os.path.join(root,file)
                    folder_name = os.path.basename(root)
                    outputfile = os.path.join(outputpath,folder_name[:-4]+"_"+file[:-4]+".json")
                    print(outputfile)
                    futures.append(executor.submit(process_image, imagefile, outputfile))
        for future in concurrent.futures.as_completed(futures):
            try:
                future.result()
            except Exception as e:
                print(f"Error processing file: {e}")
    print(count)