import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:quax/tweet/_media.dart';
import 'package:quax/tweet/_video.dart';

part 'markdown_entity.dart';
part 'image_entity.dart';
part 'video_entity.dart';
part 'link_entity.dart';
part 'divider_entity.dart';

sealed class EntityValue {
  const EntityValue();

  Widget toWidget(BuildContext context);
}
