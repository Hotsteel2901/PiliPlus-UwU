/*
 * This file is part of PiliPlus
 *
 * PiliPlus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * PiliPlus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with PiliPlus.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

const String kHotDeclaration = '''
「HOT」是本仓库在 PiliPlus 上游基础上所做的二次修改（二改）集合，原项目版权归上游作者所有，本项目同样以 GPL-3.0 开源。

二改作者：GitHub @Hotsteel2901

改版内容：
· Material 3 Expressive：超椭圆形状、表情化按钮、M3E 页面转场与动效令牌
· Haze 玻璃系统：磨砂表面、渐进模糊、可降级的性能分级与无障碍回退
· FlClash 风格悬浮底栏：弹簧镜头、拖动选择、果冻拉伸、弹性按压与触感反馈
· 控件打开动效：对话框 / 底部弹层 / 弹出菜单统一为弹簧 + 去模糊进入
· 共享元素转场：点击视频卡片放大到播放器，返回时平滑缩回卡片
· 预测性返回手势（Android 14+）：返回手势实时预览上一页

上游项目：https://github.com/bggRGjQaUbCoE/PiliPlus
二改仓库：https://github.com/Hotsteel2901/PiliPlus
本仓库为个人学习与自用改版，请勿用于商业用途；使用请遵守原项目许可。
''';

List<SettingsModel> get hotSettings => [
  SwitchModel(
    leading: const Icon(Icons.blur_on),
    title: 'Haze 玻璃效果',
    subtitle: '导航栏、提示等表面使用毛玻璃模糊，低端设备可关闭以提升流畅度',
    setKey: SettingBoxKey.enableHaze,
    defaultVal: true,
    onChanged: (value) => Get.updateMyAppTheme(),
  ),
  NormalModel(
    leading: const Icon(Icons.local_fire_department_outlined),
    title: '二改声明与改版说明',
    subtitle: '基于上游 PiliPlus 修改，遵循 GPL-3.0',
    onTap: (context, setState) => showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('二改声明'),
        content: const SingleChildScrollView(
          child: Text(kHotDeclaration, style: TextStyle(height: 1.6)),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('知道了'),
          ),
        ],
      ),
    ),
  ),
];
