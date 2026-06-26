# 宠物API接口文档

## 基础信息

- **请求域名**: `https://pet.laowaidrivetest.com`
- **数据格式**: JSON
- **字符编码**: UTF-8

## 公共参数

### 请求头

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| Authorization | string | 是 | Bearer token，登录后获取（部分接口不需要） |

### 请求参数

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

## 错误码说明

| 错误码 | 说明 |
| :--- | :--- |
| 200 | 成功 |
| 其他 | 失败，返回对应的错误信息 |

---

## 无需认证接口

### 1. 获取配置

**接口地址**: `/api/common/getConfig`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "config": {
            "key1": "value1",
            "key2": "value2"
        }
    }
}
```

### 2. 获取应用信息

**接口地址**: `/api/common/getAppInfo`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "info": {
            "id": 1,
            "name": "宠物APP",
            "logo": "https://example.com/logo.png",
            "version": "1.0.0"
        }
    }
}
```

### 3. 获取导航列表

**接口地址**: `/api/common/nav`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "list": []
    }
}
```

### 4. 获取语言列表

**接口地址**: `/api/common/getLanguage`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "list": []
    }
}
```

### 5. 获取Banner

**接口地址**: `/api/common/getBanner`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

### 6. 查询微信订单

**接口地址**: `/api/common/queryUserWxOrder`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

---

## 登录接口

### 1. UUID登录

**接口地址**: `/api/login/loginByUuid`

**请求方式**: POST/GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| uuid | string | 是 | 用户UUID |

### 2. OpenId登录

**接口地址**: `/api/login/loginByOpenId`

**请求方式**: POST/GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| openid | string | 是 | 用户OpenId |

### 3. 获取短信验证码

**接口地址**: `/api/login/getSmsCode`

**请求方式**: POST/GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| phone | string | 是 | 手机号 |

---

## 用户接口

### 1. 获取用户信息

**接口地址**: `/api/user/getUserInfo`

**请求方式**: POST/GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

### 2. 更新用户信息

**接口地址**: `/api/user/updateUserInfo`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

### 3. 更新用户头像

**接口地址**: `/api/user/updateUserAvatar`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| avatar | string | 是 | 头像URL |

### 4. 更新用户免费次数

**接口地址**: `/api/user/updateUserFreeTimes`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

### 5. 绑定手机号

**接口地址**: `/api/user/bindPhone`

**请求方式**: POST/GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

### 6. 注销账号

**接口地址**: `/api/user/cancelAccount`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

---

## 首页接口

### 1. 获取弹窗

**接口地址**: `/api/index/pop`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

### 2. 提交意见

**接口地址**: `/api/index/opinion`

**请求方式**: POST/GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| content | string | 是 | 意见内容 |

---

## 社区接口

### 1. 获取分类和Banner

**接口地址**: `/api/community/getClassifyAndBanner`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

### 2. 获取首页文章

**接口地址**: `/api/community/getArticleFroIndex`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

### 3. 获取文章详情

**接口地址**: `/api/community/getArticleDetail`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| article_id | int | 是 | 文章ID |

### 4. 获取文章评论

**接口地址**: `/api/community/getArticleComment`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| article_id | int | 是 | 文章ID |

### 5. 发表评论

**接口地址**: `/api/community/comment`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| article_id | int | 是 | 文章ID |
| content | string | 是 | 评论内容 |

### 6. 点赞

**接口地址**: `/api/community/like`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| article_id | int | 是 | 文章ID |

### 7. 取消点赞

**接口地址**: `/api/community/cancelLike`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| article_id | int | 是 | 文章ID |

### 8. 删除评论

**接口地址**: `/api/community/delComment`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| comment_id | int | 是 | 评论ID |

### 9. 添加阅读记录

**接口地址**: `/api/community/addReadLog`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| article_id | int | 是 | 文章ID |

### 10. 获取我的文章

**接口地址**: `/api/community/getMyArticle`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

### 11. 获取通知消息

**接口地址**: `/api/community/getNoticeMessage`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

### 12. 删除文章

**接口地址**: `/api/community/delArticle`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| article_id | int | 是 | 文章ID |

---

## 收藏接口

### 1. 添加收藏

**接口地址**: `/api/collect/addCollect`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| type | int | 是 | 收藏类型 |
| object_id | int | 是 | 对象ID |

### 2. 取消收藏

**接口地址**: `/api/collect/cancelCollect`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| type | int | 是 | 收藏类型 |
| object_id | int | 是 | 对象ID |

### 3. 获取收藏列表

**接口地址**: `/api/collect/getCollect`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| type | int | 否 | 收藏类型 |

---

## 订单接口

### 1. 创建订单

**接口地址**: `/api/order/addOrder`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

---

## 图片接口

### 1. 图片转PDF

**接口地址**: `/api/image/convertImagesToPDF`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| images | array | 是 | 图片URL数组 |

---

## 宠物接口

### 1. 生成宠物图片

**接口地址**: `/api/pet/generatePetImage`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| description | string | 是 | 描述内容 |
| image | string | 是 | 参考图片URL |
| style_id | int | 否 | 风格ID，有风格ID查询风格图片和描述 |

### 2. 抠图

**接口地址**: `/api/pet/mattingPetImage`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| image | string | 是 | 需要抠图的图片URL |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "task_id": "xxx"
    }
}
```

### 3. 获取抠图任务结果

**接口地址**: `/api/pet/getMattingTaskResult`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| task_id | string | 是 | 任务ID |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "status": "completed",
        "image_url": "https://example.com/xxx.png"
    }
}
```

### 4. 创建宠物档案

**接口地址**: `/api/pet/createPetProfile`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| nickname | string | 是 | 宠物昵称 |
| image | string | 是 | 宠物图片URL |
| type | int | 否 | 宠物类型：1-狗 2-猫，默认1 |
| description | string | 否 | 宠物描述 |

### 5. 获取宠物档案信息

**接口地址**: `/api/pet/getPetProfileInfo`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

### 6. 获取纪念日列表

**接口地址**: `/api/pet/getAnniversaryList`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

### 7. 获取纪念日类型列表

**接口地址**: `/api/pet/getTypes`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| language_id | int | 否 | 语言ID |

### 8. 获取纪念日类型图标列表

**接口地址**: `/api/pet/getAnniversaryTypeIcons`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| language_id | int | 否 | 语言ID |

### 9. 添加自定义纪念日类型

**接口地址**: `/api/pet/addCustomType`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| title | string | 是 | 类型标题 |
| bg_color | string | 否 | 背景颜色 |
| icon | string | 否 | 图标URL |

### 10. 编辑自定义纪念日类型

**接口地址**: `/api/pet/editCustomType`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| type_id | int | 是 | 类型ID |
| title | string | 是 | 类型标题 |
| bg_color | string | 否 | 背景颜色 |
| icon | string | 否 | 图标URL |

### 11. 删除自定义纪念日类型

**接口地址**: `/api/pet/deleteCustomType`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| type_id | int | 是 | 类型ID |

### 12. 添加纪念日

**接口地址**: `/api/pet/addAnniversary`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| name | string | 是 | 纪念日名称 |
| date | string | 是 | 日期 |
| type_id | int | 否 | 类型ID，默认0 |
| date_type | int | 否 | 日期类型，默认1 |
| repeat_frequency | int | 否 | 重复频率，默认1 |
| is_top | int | 否 | 是否置顶，默认0 |
| is_remind | int | 否 | 是否提醒，默认0 |

### 13. 编辑纪念日

**接口地址**: `/api/pet/editAnniversary`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| anniversary_id | int | 是 | 纪念日ID |
| type_id | int | 否 | 类型ID |
| name | string | 否 | 纪念日名称 |
| date | string | 否 | 日期 |
| date_type | int | 否 | 日期类型 |
| repeat_frequency | int | 否 | 重复频率 |
| is_top | int | 否 | 是否置顶 |
| is_remind | int | 否 | 是否提醒 |

### 14. 删除纪念日

**接口地址**: `/api/pet/deleteAnniversary`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| anniversary_id | int | 是 | 纪念日ID |

### 15. 切换默认宠物

**接口地址**: `/api/pet/reselectPet`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| pet_id | int | 是 | 宠物ID |

### 16. 获取字体样式列表

**接口地址**: `/api/pet/getFontStyles`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| language_id | int | 否 | 语言ID |

### 17. 获取背景图片列表

**接口地址**: `/api/pet/getBackgrounds`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| language_id | int | 否 | 语言ID |
| category_id | int | 否 | 分类ID |
| my_user_id | int | 否 | 用户ID，有传该参数才用用户ID条件 |

### 18. 获取背景分类列表

**接口地址**: `/api/pet/getBackgroundCategories`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| language_id | int | 否 | 语言ID |

### 19. 上传自定义背景

**接口地址**: `/api/pet/uploadBackground`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| image | string | 是 | 图片URL |
| name | string | 否 | 背景名称 |
| user_id | int | 否 | 用户ID |

### 20. 更新自定义背景

**接口地址**: `/api/pet/updateBackground`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| id | int | 是 | 背景ID |
| name | string | 否 | 背景名称 |
| image | string | 否 | 图片URL |
| category_id | int | 否 | 分类ID |

### 21. 删除自定义背景

**接口地址**: `/api/pet/deleteBackground`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| id | int | 是 | 背景ID |

### 22. 获取宠物风格列表

**接口地址**: `/api/pet/getPetStyles`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| language_id | int | 否 | 语言ID |

### 23. 生成带文字的GIF

**接口地址**: `/api/pet/generateImageWithTextGif`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

### 24. 获取GIF任务结果

**接口地址**: `/api/pet/getGifTaskResult`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| task_id | string | 是 | 任务ID |

---

## 相机接口

### 1. 获取音效分类列表

**接口地址**: `/api/camera/getSoundCategories`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| language_id | int | 否 | 语言ID，不传则返回通用分类 |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "list": [
            {
                "id": 1,
                "app_id": 1,
                "language_id": 0,
                "name": "动物叫声",
                "icon": "https://example.com/icons/animal.png",
                "is_show": 1,
                "sort": 1
            }
        ]
    }
}
```

### 2. 获取音效列表

**接口地址**: `/api/camera/getSoundEffects`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| language_id | int | 否 | 语言ID，不传则返回通用音效 |
| category_id | int | 否 | 分类ID，不传则返回全部分类 |
| page | int | 否 | 页码，默认1 |
| page_size | int | 否 | 每页数量，默认20 |

**排序规则**: 用户设置的排序 > 推荐 > 默认ID倒序

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "list": [
            {
                "id": 1,
                "app_id": 1,
                "language_id": 0,
                "category_id": 1,
                "name": "狗叫声",
                "sound_url": "https://example.com/sounds/dog.mp3",
                "image_url": "https://example.com/images/dog.png",
                "sound_type": 1,
                "is_recommend": 1,
                "is_show": 1,
                "sort": 1
            }
        ],
        "pagination": {
            "total": 100,
            "current_page": 1,
            "per_page": 20
        }
    }
}
```

### 3. 添加用户自定义音效

**接口地址**: `/api/camera/addCustomSoundEffect`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| name | string | 是 | 音效名称 |
| sound_url | string | 是 | 音效文件URL |
| category_id | int | 否 | 分类ID，默认0 |
| image_url | string | 否 | 音效图片URL |

**返回示例**:

```json
{
    "code": 200,
    "msg": "保存成功",
    "data": {
        "effect_id": 1
    }
}
```

### 4. 删除用户自定义音效

**接口地址**: `/api/camera/deleteCustomSoundEffect`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| effect_id | int | 是 | 音效ID |

**返回示例**:

```json
{
    "code": 200,
    "msg": "删除成功"
}
```

### 5. 设置音效排序

**接口地址**: `/api/camera/setSoundEffectSort`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| effect_id | int | 是 | 音效ID |
| sort | int | 否 | 排序值，默认0 |

**返回示例**:

```json
{
    "code": 200,
    "msg": "保存成功"
}
```

### 6. 保存摄像头记录

**接口地址**: `/api/camera/saveCameraRecord`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| file_url | string | 是 | 文件URL（图片或视频） |
| record_type | int | 否 | 记录类型：1-图片 2-视频，默认1 |
| sound_effect_id | int | 否 | 使用的音效ID |
| thumbnail_url | string | 否 | 缩略图URL（视频时使用） |
| duration | int | 否 | 视频时长（秒） |

**返回示例**:

```json
{
    "code": 200,
    "msg": "保存成功",
    "data": {
        "record_id": 1
    }
}
```

### 7. 获取摄像头记录列表

**接口地址**: `/api/camera/getCameraRecords`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| record_type | int | 否 | 记录类型：1-图片 2-视频 |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "list": [
            {
                "id": 1,
                "app_id": 1,
                "user_id": 1001,
                "record_type": 1,
                "file_url": "https://example.com/camera/photo_123.jpg",
                "thumbnail_url": null,
                "duration": 0,
                "sound_effect_id": 1,
                "is_show": 1,
                "created_at": "2024-01-01 10:00:00"
            }
        ],
        "pagination": {
            "total": 100,
            "current_page": 1,
            "per_page": 20
        }
    }
}
```

### 8. 删除摄像头记录

**接口地址**: `/api/camera/deleteCameraRecord`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| record_id | int | 是 | 记录ID |

**返回示例**:

```json
{
    "code": 200,
    "msg": "删除成功"
}
```

### 9. 删除所有摄像头记录

**接口地址**: `/api/camera/deleteAllCameraRecords`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| user_id | int | 是 | 用户ID |

**返回示例**:

```json
{
    "code": 200,
    "msg": "删除成功"
}
```

---

## 基础接口

### 1. 文件上传

**接口地址**: `/api/base/upload`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| file | file | 是 | 文件 |
| type | string | 否 | 文件类型 |
| path | string | 否 | 存储路径 |

### 2. 删除文件

**接口地址**: `/api/base/delFile`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| url | string | 是 | 文件URL |

---

## 后台管理接口

### 音效管理

#### 1. 导入音效数据

**接口地址**: `/admin/camera/importSoundData`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| data | string | 是 | JSON格式的数据，包含categories和effects |

**data参数结构**:

```json
{
    "categories": [
        {
            "id": 1,
            "name": "动物叫声",
            "language_id": 0,
            "icon": "https://example.com/icons/animal.png",
            "sort": 1
        }
    ],
    "effects": [
        {
            "id": 1,
            "category_id": 1,
            "name": "狗叫声",
            "sound_url": "https://example.com/sounds/dog.mp3",
            "image_url": "https://example.com/images/dog.png",
            "language_id": 0,
            "sound_type": 1,
            "is_recommend": 1,
            "sort": 1
        }
    ]
}
```

**返回示例**:

```json
{
    "code": 200,
    "msg": "导入成功",
    "data": {
        "category_count": 5,
        "effect_count": 20
    }
}
```