#include <stdint.h>

#include "qcms.h"

static void transform(qcms_profile* src_profile, qcms_profile* dst_profile,
                      int alpha) {
  // qcms supports GRAY and RGB profiles as input, and RGB as output.
  // Note that function qcms_transform_create further below also checks
  // this, yet quitting early here gives slightly better performance.

  uint32_t src_color_space = qcms_profile_get_color_space(src_profile);
  qcms_data_type src_type;
  if (src_color_space == icSigGrayData)
    src_type = alpha & 1 ? QCMS_DATA_GRAYA_8 : QCMS_DATA_GRAY_8;
  else if (src_color_space == icSigRgbData)
    src_type = alpha & 1 ? QCMS_DATA_RGBA_8 : QCMS_DATA_RGB_8;
  else
    return;

  uint32_t dst_color_space = qcms_profile_get_color_space(dst_profile);
  if (dst_color_space != icSigRgbData)
    return;
  qcms_data_type dst_type = alpha & 2 ? QCMS_DATA_RGBA_8 : QCMS_DATA_RGB_8;

  qcms_intent intent = qcms_profile_get_rendering_intent(src_profile);
  qcms_profile_precache_output_transform(dst_profile);

  qcms_transform* transform = qcms_transform_create(
    src_profile, src_type, dst_profile, dst_type, intent);
  if (!transform)
    return;

  static uint8_t src[] = {
    0x7F, 0x7F, 0x7F, 0x00, 0x00, 0x7F, 0x7F, 0xFF, 0x7F, 0x10, 0x20, 0x30,
  };
  static uint8_t dst[sizeof(src) * 4]; // 4x in case of GRAY to RGBA

  int src_bytes_per_pixel = 4; // QCMS_DATA_RGBA_8
  if (src_type == QCMS_DATA_RGB_8)
    src_bytes_per_pixel = 3;
  else if (src_type == QCMS_DATA_GRAYA_8)
    src_bytes_per_pixel = 2;
  else if (src_type == QCMS_DATA_GRAY_8)
    src_bytes_per_pixel = 1;

  qcms_transform_data(transform, src, dst, sizeof(src) / src_bytes_per_pixel);
  qcms_transform_release(transform);
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  qcms_enable_iccv4();

  qcms_profile* profile = qcms_profile_from_memory(data, size);
  if (!profile)
    return 0;

  // Firefox respects this check, but ignoring it gives slightly higher
  // coverage. It only checks part of the profile for reasonable values,
  // to not render output caused by likely broken profiles.
  if (qcms_profile_is_bogus(profile)) {};

  qcms_profile* srgb_profile = qcms_profile_sRGB();
  if (!srgb_profile) {
    qcms_profile_release(profile);
    return 0;
  }

  transform(profile, srgb_profile, size & 3);
  transform(srgb_profile, profile, size & 3);

  qcms_profile_release(profile);
  qcms_profile_release(srgb_profile);

  return 0;
}
