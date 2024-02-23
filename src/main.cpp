#include <filesystem>
#include <iostream>
#include <memory>
#include <optional>
#include <stdexcept>
#include <vector>

#include <espeak-ng/speak_lib.h>

#include "json.hpp"
#include "phonemize.hpp"
#include "tashkeel.hpp"
#include "uni_algo.h"

using json = nlohmann::json;

// ----------------------------------------------------------------------------

int main() {
  piper::eSpeakPhonemeConfig eSpeakConfig;
  tashkeel::State tashkeelState;

    int result =
        espeak_Initialize(AUDIO_OUTPUT_SYNCHRONOUS, 0,
                          "share/espeak-ng-data", 0);
    if (result < 0) {
      throw std::runtime_error("Failed to initialize eSpeak");
    }

      // Load tashkeel
      tashkeel::tashkeel_load("share/libtashkeel_model.ort",
                              tashkeelState);

  // Process each line as a JSON object, adding phonemes and phoneme ids.
  std::string line;
  while (std::getline(std::cin, line)) {
    json lineObj;
      // Each line is JSON object with:
      // {
      //   "lang": "eSpeak voice"
      //   "text": "Text to phonemize"
      // }
      lineObj = json::parse(line);

    auto lang = lineObj["lang"].get<std::string>();
    auto text = lineObj["text"].get<std::string>();
    std::string processedText;

    if (lang == "ar") {
      processedText = tashkeel::tashkeel_run(text, tashkeelState);
    } else {
      processedText = text;
    }

    std::vector<std::vector<piper::Phoneme>> phonemes;
      // Phonemize text
      eSpeakConfig.voice = lang;
      piper::phonemize_eSpeak(processedText, eSpeakConfig, phonemes);

      // Copy to JSON object
      std::vector<std::vector<std::string>> linePhonemes;
      for (auto &sentencePhonemes : phonemes) {
        std::vector<std::string> sentence;
        for (auto phoneme : sentencePhonemes) {
          // Convert to UTF-8 string
          std::u32string phonemeU32Str;
          phonemeU32Str += phoneme;
          sentence.push_back(una::utf32to8(phonemeU32Str));
        }
        linePhonemes.push_back(sentence);
      }

      lineObj["phonemes"] = linePhonemes;

    std::cout << lineObj.dump() << std::endl;
  }

    // Terminate eSpeak
    espeak_Terminate();

  return 0;
}
