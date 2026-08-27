import 'package:dio/dio.dart';

import '../../core/network/api_compatibility.dart';
import '../../core/network/api_response_parser.dart';
import '../../core/network/dio_client.dart';
import '../dto/common/page_result.dart';
import '../dto/website/website_acme_account_dto.dart';
import '../dto/website/website_create_req.dart';
import '../dto/website/website_config_file_dto.dart';
import '../dto/website/website_detail_dto.dart';
import '../dto/website/website_dir_dto.dart';
import '../dto/website/website_index_config_dto.dart';
import '../dto/website/website_limit_config_dto.dart';
import '../dto/website/website_log_dto.dart';
import '../dto/website/website_proxy_dto.dart';
import '../dto/website/website_auth_dto.dart';
import '../dto/website/website_auth_req.dart';
import '../dto/website/website_domain_req.dart';
import '../dto/website/website_dto.dart';
import '../dto/website/website_redirect_dto.dart';
import '../dto/website/openresty_performance_dto.dart';
import '../dto/website/website_https_dto.dart';
import '../dto/website/website_search_req.dart';
import '../dto/website/website_ssl_dto.dart';
import '../dto/website/website_leech_dto.dart';
import '../dto/website/website_real_ip_dto.dart';
import '../dto/website/website_cors_dto.dart';
import '../dto/website/website_update_req.dart';
import '../dto/website/website_resource_dto.dart';
import '../dto/cronjob/cronjob_form_data_dto.dart';
import '../dto/website/openresty_status_dto.dart';
import '../dto/website/ssl_manage_dtos.dart';

/// 网站 API。
///
/// 对应 1Panel `/websites` 相关接口。
class WebsiteApi {
  WebsiteApi(this._client);

  final DioClient _client;

  /// 分页查询网站列表
  Future<PageResult<WebsiteDto>> searchWebsites(WebsiteSearchReq req) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/search',
      data: req.toJson(),
    );

    return PageResult<WebsiteDto>.fromJson(
      ApiResponseParser.map(resp),
      WebsiteDto.fromJson,
    );
  }

  /// 获取网站选项列表（用于下拉选择）。
  Future<List<WebsiteOptionDto>> getWebsiteOptions() async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/options',
      data: {},
    );
    return ApiResponseParser.list(resp, WebsiteOptionDto.fromJson);
  }

  /// 创建网站
  Future<void> createWebsite(WebsiteCreateReq req) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites',
      data: req.toJson(),
    );
  }

  /// 查询网站详情。
  Future<WebsiteDetailDto> getWebsite(int id) async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/websites/$id',
    );
    return ApiResponseParser.object(resp, WebsiteDetailDto.fromJson);
  }

  /// 查询 ACME 账号。手动创建（id=0）由调用方插入。
  Future<List<WebsiteAcmeAccountDto>> searchAcmeAccounts() async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/acme/search',
      data: const {'page': 1, 'pageSize': 200},
    );
    final result = PageResult<WebsiteAcmeAccountDto>.fromJson(
      ApiResponseParser.map(resp),
      WebsiteAcmeAccountDto.fromJson,
    );
    return result.items;
  }

  /// 按 ACME 账号查询可用证书。
  Future<List<WebsiteSslDto>> listWebsiteSsl(int acmeAccountId) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/ssl/list',
      data: {'acmeAccountID': '$acmeAccountId'},
    );
    if (resp.data?['data'] == null) return const [];
    return ApiResponseParser.list(resp, WebsiteSslDto.fromJson);
  }

  /// 查询网站域名列表。
  Future<List<WebsiteDomainDto>> listDomains(int websiteId) async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/websites/domains/$websiteId',
    );
    return ApiResponseParser.list(resp, WebsiteDomainDto.fromJson);
  }

  /// 新增网站域名。
  Future<void> addDomains(int websiteId, List<WebsiteDomainReq> domains) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/domains',
      data: {
        'websiteID': websiteId,
        'domains': domains.map((domain) => domain.toJson()).toList(),
        'domainStr': '',
      },
    );
  }

  /// 更新域名 SSL 状态。
  Future<void> updateDomainSsl(int domainId, bool ssl) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/domains/update',
      data: {'id': domainId, 'ssl': ssl},
    );
  }

  /// 删除网站域名。
  Future<void> deleteDomain(int domainId) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/domains/del',
      data: {'id': domainId},
    );
  }

  /// 查询网站目录配置。
  Future<WebsiteDirDto> getWebsiteDir(int websiteId) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/dir',
      data: {'id': websiteId},
    );
    return ApiResponseParser.object(resp, WebsiteDirDto.fromJson);
  }

  /// 更新运行目录并重载。
  Future<void> updateWebsiteSiteDir(int websiteId, String siteDir) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/dir/update',
      data: {'id': websiteId, 'siteDir': siteDir},
    );
  }

  /// 更新网站运行用户/组权限。
  Future<void> updateWebsiteDirPermission(
    int websiteId, {
    required String user,
    required String group,
  }) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/dir/permission',
      data: {'id': websiteId, 'user': user, 'group': group},
    );
  }

  /// 加载默认文档（index）配置。
  Future<WebsiteIndexConfigDto> getWebsiteIndexConfig(int websiteId) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/config',
      data: {
        'operate': 'update',
        'scope': 'index',
        'websiteId': websiteId,
        'params': <String, dynamic>{},
      },
    );
    return ApiResponseParser.object(resp, WebsiteIndexConfigDto.fromJson);
  }

  /// 保存默认文档列表（多行文本，与面板一致）。
  Future<void> updateWebsiteIndexConfig(
    int websiteId,
    List<String> indexFiles,
  ) async {
    final body = indexFiles.join('\n');
    final indexParam = body.isEmpty ? '' : '$body\n';
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/config/update',
      data: {
        'operate': 'update',
        'scope': 'index',
        'websiteId': websiteId,
        'params': {'index': indexParam},
      },
    );
  }

  /// 加载流量限制（limit-conn）配置。
  Future<WebsiteLimitConfigDto> getWebsiteLimitConfig(int websiteId) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/config',
      data: {'scope': 'limit-conn', 'websiteId': websiteId},
    );
    return ApiResponseParser.object(resp, WebsiteLimitConfigDto.fromJson);
  }

  /// 保存流量限制配置。
  Future<void> updateWebsiteLimitConfig(
    int websiteId, {
    required bool enable,
    required int perServerLimit,
    required int perIpLimit,
    required int rateKb,
  }) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/config/update',
      data: {
        'operate': enable ? 'add' : 'delete',
        'scope': 'limit-conn',
        'websiteId': websiteId,
        'params': [
          {'limit_conn': 'perserver $perServerLimit'},
          {'limit_conn': 'perip $perIpLimit'},
          {'limit_rate': '${rateKb}k'},
        ],
      },
    );
  }

  /// 查询反向代理配置列表。
  Future<List<WebsiteProxyDto>> listWebsiteProxies(int websiteId) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/proxies',
      data: {'id': websiteId},
    );
    final raw = resp.data?['data'];
    if (raw == null) return const [];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(WebsiteProxyDto.fromJson)
        .toList(growable: false);
  }

  /// 创建/编辑反向代理配置。
  Future<void> updateWebsiteProxy(Map<String, dynamic> payload) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/proxies/update',
      data: payload,
    );
  }

  /// 删除反向代理配置。
  Future<void> deleteWebsiteProxy(int websiteId, String name) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/proxies/delete',
      data: {'id': websiteId, 'name': name},
    );
  }

  /// 启用/停用反向代理配置。
  Future<void> updateWebsiteProxyStatus(
    int websiteId,
    String name,
    String status,
  ) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/proxies/status',
      data: {'id': websiteId, 'name': name, 'status': status},
    );
  }

  /// 直接保存反向代理源文内容。
  Future<void> updateWebsiteProxyFile(
    int websiteId,
    String name,
    String content,
  ) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/proxies/file',
      data: {'websiteID': websiteId, 'name': name, 'content': content},
    );
  }

  /// 查询网站密码访问配置 (全局)。
  Future<WebsiteAuthDto> getWebsiteAuth(int websiteId) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/auths',
      data: {'websiteID': websiteId},
    );
    return ApiResponseParser.object(resp, WebsiteAuthDto.fromJson);
  }

  /// 查询网站路径密码访问列表。
  Future<List<WebsitePathAuthItemDto>> listWebsitePathAuths(
    int websiteId,
  ) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/auths/path',
      data: {'websiteID': websiteId},
    );
    if (resp.data?['data'] == null) return const [];
    return ApiResponseParser.list(resp, WebsitePathAuthItemDto.fromJson);
  }

  /// 更新网站密码访问配置 (全局: 创建、修改、删除、启用、禁用)。
  Future<void> updateWebsiteAuth(WebsiteAuthUpdateReq req) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/auths/update',
      data: req.toJson(),
    );
  }

  /// 更新网站路径密码访问配置 (创建、修改、删除)。
  Future<void> updateWebsitePathAuth(WebsitePathAuthUpdateReq req) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/auths/path/update',
      data: req.toJson(),
    );
  }

  /// 查询 OpenResty 运行状态（Nginx stub_status）。
  Future<OpenRestyStatusDto> getOpenRestyStatus() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/openresty/status',
    );
    return ApiResponseParser.object(resp, OpenRestyStatusDto.fromJson);
  }

  /// 获取 OpenResty 性能调整参数。
  Future<List<OpenRestyPerformanceItemDto>> getOpenRestyPerformance() async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/openresty/scope',
      data: {'scope': 'http-per'},
    );
    return ApiResponseParser.list(resp, OpenRestyPerformanceItemDto.fromJson);
  }

  /// 更新 OpenResty 性能调整参数。
  Future<void> updateOpenRestyPerformance(Map<String, String> params) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/openresty/update',
      data: {'scope': 'http-per', 'operate': 'update', 'params': params},
    );
  }

  /// 查询 OpenResty 主配置文件内容。
  Future<WebsiteConfigFileDto> getOpenRestyConfig() async {
    final resp = await _client.get<Map<String, dynamic>>('/api/v2/openresty');
    return ApiResponseParser.object(resp, WebsiteConfigFileDto.fromJson);
  }

  /// 更新 OpenResty 主配置文件内容并重载。
  Future<void> updateOpenRestyConfig(String content) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/openresty/file',
      data: {'content': content, 'backup': false},
    );
  }

  /// 查询网站 OpenResty 配置文件内容。
  Future<WebsiteConfigFileDto> getWebsiteConfig(int websiteId) async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/websites/$websiteId/config/openresty',
    );
    return ApiResponseParser.object(resp, WebsiteConfigFileDto.fromJson);
  }

  /// 更新网站 Nginx 配置文件内容并重载。
  Future<void> updateWebsiteConfig(int websiteId, String content) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/nginx/update',
      data: {'id': websiteId, 'content': content},
    );
  }

  /// 更新网站基础信息。
  Future<void> updateWebsite(WebsiteUpdateReq req) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/update',
      data: req.toJson(),
    );
  }

  /// 启用、禁用或清空网站日志。
  Future<void> operateWebsiteLog(
    int websiteId, {
    required WebsiteLogType type,
    required String operate,
  }) async {
    final data = {
      'id': websiteId,
      'operate': operate,
      'logType': type.fileName,
    };
    await ApiCompatibility.tryVariants<void>(
      [
        ApiEndpointVariant(
          name: 'websites.log.operate',
          call: () async {
            await _client.post<Map<String, dynamic>>(
              '/api/v2/websites/log/operate',
              data: data,
            );
          },
        ),
        ApiEndpointVariant(
          name: 'websites.log.legacy',
          call: () async {
            await _client.post<Map<String, dynamic>>(
              '/api/v2/websites/log',
              data: data,
            );
          },
        ),
      ],
      cacheScope: _client,
      cacheKey: 'websites.log.operate',
    );
  }

  /// 查询网站防盗链配置。
  Future<WebsiteLeechDto> getWebsiteLeech(int websiteId) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/leech',
      data: {'websiteID': websiteId},
    );
    return ApiResponseParser.object(resp, WebsiteLeechDto.fromJson);
  }

  /// 更新网站防盗链配置。
  Future<void> updateWebsiteLeech(WebsiteLeechUpdateReq req) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/leech/update',
      data: req.toJson(),
    );
  }

  /// 查询网站真实 IP 配置。
  Future<WebsiteRealIpDto> getWebsiteRealIp(int websiteId) async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/websites/realip/config/$websiteId',
    );
    return ApiResponseParser.object(resp, WebsiteRealIpDto.fromJson);
  }

  /// 更新网站真实 IP 配置。
  Future<void> updateWebsiteRealIp(WebsiteRealIpDto req) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/realip/config',
      data: req.toJson(),
    );
  }

  /// 查询网站跨域配置。
  Future<WebsiteCorsDto> getWebsiteCors(int websiteId) async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/websites/cors/$websiteId',
    );
    return ApiResponseParser.object(resp, WebsiteCorsDto.fromJson);
  }

  /// 更新网站跨域配置。
  Future<void> updateWebsiteCors(WebsiteCorsDto req) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/cors/update',
      data: req.toJson(),
    );
  }

  /// 获取伪静态内容。
  Future<String> getRewriteContent(int websiteId, String name) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/rewrite',
      data: {'websiteID': websiteId, 'name': name},
    );
    return ApiResponseParser.object(
      resp,
      (data) => data['content'] as String? ?? '',
    );
  }

  /// 获取自定义伪静态模板列表。
  Future<List<String>> getCustomRewriteTemplates() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/websites/rewrite/custom',
    );
    final data = resp.data?['data'];
    if (data == null) return [];
    if (data is! List) return [];
    return data.map((e) => e.toString()).toList();
  }

  /// 更新伪静态配置。
  Future<void> updateRewrite(int websiteId, String name, String content) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/rewrite/update',
      data: {'websiteID': websiteId, 'name': name, 'content': content},
    );
  }

  /// 管理自定义伪静态模板（创建/删除）。
  Future<void> manageCustomRewrite({
    required String name,
    required String operate,
    String? content,
  }) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/rewrite/custom',
      data: {'name': name, 'operate': operate, 'content': content},
    );
  }

  /// 获取网站重定向规则列表。
  Future<List<WebsiteRedirectDto>> getWebsiteRedirects(int websiteId) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/redirect',
      data: {'websiteID': websiteId},
    );
    final data = resp.data?['data'];
    if (data == null) return [];
    return ApiResponseParser.list(resp, WebsiteRedirectDto.fromJson);
  }

  /// 更新网站重定向规则（创建/编辑/开关/删除）。
  Future<void> updateWebsiteRedirect(Map<String, dynamic> req) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/redirect/update',
      data: req,
    );
  }

  /// 保存重定向规则源文件。
  Future<void> saveWebsiteRedirectFile(
    int websiteId,
    String name,
    String content,
  ) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/redirect/file',
      data: {'websiteID': websiteId, 'name': name, 'content': content},
    );
  }

  /// 获取网站 HTTPS 配置。
  Future<WebsiteHttpsDto> getWebsiteHttps(int websiteId) async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/websites/$websiteId/https',
    );
    return ApiResponseParser.object(resp, WebsiteHttpsDto.fromJson);
  }

  /// 更新网站 HTTPS 配置。
  Future<void> updateWebsiteHttps(
    int websiteId,
    Map<String, dynamic> req,
  ) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/$websiteId/https',
      data: req,
    );
  }

  // ===========================================================================
  // SSL 证书管理
  // ===========================================================================

  /// 搜索 SSL 证书。
  Future<PageResult<SslManageDto>> searchSsl(Map<String, dynamic> req) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/ssl/search',
      data: req,
    );
    return PageResult<SslManageDto>.fromJson(
      ApiResponseParser.map(resp),
      SslManageDto.fromJson,
    );
  }

  /// 查询 SSL 证书详情。
  Future<SslManageDto> getSsl(int id) async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/websites/ssl/$id',
    );
    return ApiResponseParser.object(resp, SslManageDto.fromJson);
  }

  /// 创建 SSL 证书。
  Future<void> createSsl(SslCreateReq req) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/ssl',
      data: req.toJson(),
    );
  }

  /// 更新 SSL 证书。
  Future<void> updateSsl(SslUpdateReq req) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/ssl/update',
      data: req.toJson(),
    );
  }

  /// 删除 SSL 证书。
  Future<void> deleteSsl(List<int> ids) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/ssl/del',
      data: {'ids': ids},
    );
  }

  /// 申请/续签 SSL 证书。
  Future<void> obtainSsl(int id) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/ssl/obtain',
      data: {'sslId': id},
    );
  }

  /// 查询 SSL DNS 解析记录。
  Future<List<SslResolveDto>> resolveSsl(int acmeId, int sslId) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/ssl/resolve',
      data: {'acmeAccountId': acmeId, 'sslId': sslId},
    );
    return ApiResponseParser.list(resp, SslResolveDto.fromJson);
  }

  /// 上传 SSL 证书。
  ///
  /// [type] 为 `paste` 时需传 [certificate] 和 [privateKey]；
  /// [type] 为 `local` 时需传 [certificatePath] 和 [privateKeyPath]。
  Future<void> uploadSsl({
    required String type,
    String? certificate,
    String? privateKey,
    String? certificatePath,
    String? privateKeyPath,
    String? description,
    int? domainId,
    int? websiteSSLId,
  }) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/ssl/upload',
      data: {
        'type': type,
        if (certificate != null) 'certificate': certificate,
        if (privateKey != null) 'privateKey': privateKey,
        if (certificatePath != null) 'certificatePath': certificatePath,
        if (privateKeyPath != null) 'privateKeyPath': privateKeyPath,
        if (description != null) 'description': description,
        if (domainId != null) 'domainId': domainId,
        if (websiteSSLId != null) 'websiteSSLId': websiteSSLId,
      },
    );
  }

  /// 通过本地文件上传 SSL 证书（multipart）。
  Future<void> uploadSslByFile({
    required String certificatePath,
    required String privateKeyPath,
    String? description,
    int? websiteSSLId,
  }) async {
    final formData = FormData.fromMap({
      'type': 'upload',
      'certificateFile': await MultipartFile.fromFile(certificatePath),
      'privateKeyFile': await MultipartFile.fromFile(privateKeyPath),
      if (description != null) 'description': description,
      if (websiteSSLId != null) 'websiteSSLId': websiteSSLId,
    });
    await _client.postMultipart<Map<String, dynamic>>(
      '/api/v2/websites/ssl/upload/file',
      formData: formData,
    );
  }

  /// 下载 SSL 证书（返回二进制数据）。
  Future<Response<dynamic>> downloadSsl(int id) async {
    return _client.post<dynamic>(
      '/api/v2/websites/ssl/download',
      data: {'sslId': id},
      options: Options(responseType: ResponseType.bytes),
    );
  }

  // ===========================================================================
  // ACME 账号管理
  // ===========================================================================

  /// 搜索 ACME 账号（分页）。
  Future<PageResult<WebsiteAcmeAccountDto>> searchAcmeAccountsPaged(
    Map<String, dynamic> req,
  ) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/acme/search',
      data: req,
    );
    return PageResult<WebsiteAcmeAccountDto>.fromJson(
      ApiResponseParser.map(resp),
      WebsiteAcmeAccountDto.fromJson,
    );
  }

  /// 创建 ACME 账号。
  Future<void> createAcmeAccount(AcmeAccountCreateReq req) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/acme',
      data: req.toJson(),
    );
  }

  /// 更新 ACME 账号。
  Future<void> updateAcmeAccount(Map<String, dynamic> req) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/acme/update',
      data: req,
    );
  }

  /// 删除 ACME 账号。
  Future<void> deleteAcmeAccount(int id) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/acme/del',
      data: {'id': id},
    );
  }

  // ===========================================================================
  // DNS 账号管理
  // ===========================================================================

  /// 搜索 DNS 账号（分页）。
  Future<PageResult<DnsAccountDto>> searchDnsAccounts(
    Map<String, dynamic> req,
  ) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/dns/search',
      data: req,
    );
    return PageResult<DnsAccountDto>.fromJson(
      ApiResponseParser.map(resp),
      DnsAccountDto.fromJson,
    );
  }

  /// 创建 DNS 账号。
  Future<void> createDnsAccount(DnsAccountCreateReq req) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/dns',
      data: req.toJson(),
    );
  }

  /// 更新 DNS 账号。
  Future<void> updateDnsAccount(Map<String, dynamic> req) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/dns/update',
      data: req,
    );
  }

  /// 删除 DNS 账号。
  Future<void> deleteDnsAccount(int id) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/dns/del',
      data: {'id': id},
    );
  }

  // ===========================================================================
  // 自签 CA 管理
  // ===========================================================================

  /// 搜索自签 CA（分页）。
  Future<PageResult<CaDto>> searchCaAccounts(Map<String, dynamic> req) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/ca/search',
      data: req,
    );
    return PageResult<CaDto>.fromJson(
      ApiResponseParser.map(resp),
      CaDto.fromJson,
    );
  }

  /// 查询自签 CA 详情。
  Future<CaDto> getCaDetail(int id) async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/websites/ca/$id',
    );
    return ApiResponseParser.object(resp, CaDto.fromJson);
  }

  /// 创建自签 CA。
  Future<void> createCa(CaCreateReq req) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/ca',
      data: req.toJson(),
    );
  }

  /// 用 CA 签发证书。
  Future<void> obtainCa(CaObtainReq req) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/ca/obtain',
      data: req.toJson(),
    );
  }

  /// 续签 CA 证书。
  Future<void> renewCa(int sslId) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/ca/renew',
      data: {'sslId': sslId},
    );
  }

  /// 删除自签 CA。
  Future<void> deleteCa(int id) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/ca/del',
      data: {'id': id},
    );
  }

  /// 下载 CA 证书（返回二进制数据）。
  Future<Response<dynamic>> downloadCa(int id) async {
    return _client.post<dynamic>(
      '/api/v2/websites/ca/download',
      data: {'id': id},
      options: Options(responseType: ResponseType.bytes),
    );
  }

  /// 切换网站 PHP 版本（或切换为静态网站）。
  ///
  /// [runtimeID] 为 0 时表示切换为静态网站，其他值表示切换到对应的 PHP 运行环境。
  Future<void> switchPhpVersion(int websiteId, int runtimeId) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/php/version',
      data: {'websiteID': websiteId, 'runtimeID': runtimeId},
    );
  }

  /// 获取网站关联的资源列表。
  Future<List<WebsiteResourceDto>> getWebsiteResources(int websiteId) async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/websites/resource/$websiteId',
    );
    return ApiResponseParser.list(resp, WebsiteResourceDto.fromJson);
  }

  /// 获取可关联的数据库列表。
  Future<List<WebsiteDatabaseDto>> getWebsiteDatabases() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/websites/databases',
    );
    return ApiResponseParser.list(resp, WebsiteDatabaseDto.fromJson);
  }

  /// 更换网站关联的数据库。
  Future<void> changeWebsiteDatabase(WebsiteChangeDatabaseReq req) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/websites/databases',
      data: req.toJson(),
    );
  }
}
