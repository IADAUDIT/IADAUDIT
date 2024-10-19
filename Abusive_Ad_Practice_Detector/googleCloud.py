import io
import os
import json
import shutil

from google.cloud import vision

def detect_safe_search(ipafile ,file):
    # input your google cloud json file path
    os.environ[
        "GOOGLE_APPLICATION_CREDENTIALS"] = r"xxx.json"
    client = vision.ImageAnnotatorClient()

    result_list = []
    # your output file path
    outputfile = os.path.join(r"xxxx")
    if os.path.exists(outputfile):
        return
    print(outputfile)
    for mediapath in os.listdir(ipafile):
        try:
            mediapath = os.path.join(ipafile,mediapath)
            print(mediapath)
            with open(mediapath, "rb") as image_file:
                content = image_file.read()

            image = vision.Image(content=content)

            response = client.safe_search_detection(image=image)
            safe = response.safe_search_annotation

            # Names of likelihood from google.cloud.vision.enums
            likelihood_name = (
                "UNKNOWN",
                "VERY_UNLIKELY",
                "UNLIKELY",
                "POSSIBLE",
                "LIKELY",
                "VERY_LIKELY",
            )
            print("Safe search:")

            print(f"adult: {likelihood_name[safe.adult]}")
            print(f"medical: {likelihood_name[safe.medical]}")
            print(f"spoofed: {likelihood_name[safe.spoof]}")
            print(f"violence: {likelihood_name[safe.violence]}")
            print(f"racy: {likelihood_name[safe.racy]}")

            result_dict = {
                "mediapath": mediapath,
                "adult": likelihood_name[safe.adult],
                "medical": likelihood_name[safe.medical],
                "spoofed": likelihood_name[safe.spoof],
                "violence": likelihood_name[safe.violence],
                "racy": likelihood_name[safe.racy],
            }
            result_list.append(result_dict)

            if response.error.message:
                raise Exception(
                    "{}\nFor more info on error messages, check: "
                    "https://cloud.google.com/apis/design/errors".format(response.error.message)
                )
        except Exception as e:
            print(f"An error occurred: {str(e)}")
    with open(outputfile, "w", encoding="utf-8") as f:
        json.dump(result_list, f, ensure_ascii=False, indent=4)


if __name__ == '__main__':
    # your image file path
    testpath = r"xxx"
    for file in os.listdir(testpath):
        ipapath = os.path.join(testpath,file)
        detect_safe_search(ipapath, file)

