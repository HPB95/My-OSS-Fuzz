#include "fuzz.h"
#include "webp/decode.h"

int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  WebPDecoderConfig config;
  if (!WebPInitDecoderConfig(&config))
    return 0;
  if (WebPGetFeatures(data, size, &config.input) != VP8_STATUS_OK)
    return 0;
  if ((size_t)config.input.width * config.input.height > fuzz_px_limit)
    return 0;

  // Using two independent criteria ensures that all combinations of options
  // can reach each path at the decoding stage, with meaningful differences.

  const uint8_t value = fuzz_hash(data, size);
  float factor = value / 255.f; // 0-1

  config.options.flip = value & 1;
  config.options.bypass_filtering = value & 2;
  config.options.no_fancy_upsampling = value & 4;
  config.options.use_threads = value & 8;
  if (size & 1) {
    config.options.use_cropping = 1;
    config.options.crop_width = (int)(config.input.width * (1 - factor));
    config.options.crop_height = (int)(config.input.height * (1 - factor));
    config.options.crop_left = config.input.width - config.options.crop_width;
    config.options.crop_top = config.input.height - config.options.crop_height;
  }
  if (size & 2) {
    int strength = (int)(factor * 100);
    config.options.dithering_strength = strength;
    config.options.alpha_dithering_strength = 100 - strength;
  }
  if (size & 4) {
    config.options.use_scaling = 1;
    config.options.scaled_width = (int)(config.input.width * factor * 2);
    config.options.scaled_height = (int)(config.input.height * factor * 2);
  }

  config.output.colorspace = (WEBP_CSP_MODE)(value % MODE_LAST);

  if (size % 3) {
    // Decodes incrementally in chunks of increasing size.
    WebPIDecoder* idec = WebPIDecode(NULL, 0, &config);
    if (!idec)
      return 0;
    VP8StatusCode status;
    if (size & 8) {
      size_t available_size = value + 1;
      while (1) {
        if (available_size > size)
          available_size = size;
        status = WebPIUpdate(idec, data, available_size);
        if (status != VP8_STATUS_SUSPENDED || available_size == size)
          break;
        available_size *= 2;
      }
    } else {
      // WebPIAppend expects new data and its size with each call.
      // Implemented here by simply advancing the pointer into data.
      const uint8_t* new_data = data;
      size_t new_size = value + 1;
      while (1) {
        if (new_data + new_size > data + size)
          new_size = data + size - new_data;
        status = WebPIAppend(idec, new_data, new_size);
        if (status != VP8_STATUS_SUSPENDED || new_size == 0)
          break;
        new_data += new_size;
        new_size *= 2;
      }
    }
    WebPIDelete(idec);
  } else {
    WebPDecode(data, size, &config);
  }

  WebPFreeDecBuffer(&config.output);
  return 0;
}
