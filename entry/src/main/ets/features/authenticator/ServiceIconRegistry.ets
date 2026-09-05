export enum ServiceIconKey {
  ALIBABA_CLOUD = 'ALIBABA_CLOUD',
  TENCENT_CLOUD = 'TENCENT_CLOUD',
  HUAWEI_CLOUD = 'HUAWEI_CLOUD',
  BAIDU_AI_CLOUD = 'BAIDU_AI_CLOUD',
  VOLCANO_ENGINE = 'VOLCANO_ENGINE',
  GOOGLE = 'GOOGLE',
  MICROSOFT = 'MICROSOFT',
  GITHUB = 'GITHUB',
  APPLE = 'APPLE',
  AWS = 'AWS',
  CLOUDFLARE = 'CLOUDFLARE',
  STEAM = 'STEAM',
  DISCORD = 'DISCORD',
  DROPBOX = 'DROPBOX',
  SLACK = 'SLACK',
  BITWARDEN = 'BITWARDEN',
  ONE_PASSWORD = 'ONE_PASSWORD',
  GITLAB = 'GITLAB',
  PROTON = 'PROTON',
  OPENAI = 'OPENAI'
}

export interface ServiceIconMatch {
  key: ServiceIconKey;
  backgroundColor: string;
}

interface ServiceIconDefinition extends ServiceIconMatch {
  aliases: string[];
}

const SERVICE_ICONS: ServiceIconDefinition[] = [
  { key: ServiceIconKey.ALIBABA_CLOUD, backgroundColor: '#FF6A00', aliases: ['alibabacloud', 'aliyun', '阿里云'] },
  { key: ServiceIconKey.TENCENT_CLOUD, backgroundColor: '#0052D9', aliases: ['tencentcloud', '腾讯云'] },
  { key: ServiceIconKey.HUAWEI_CLOUD, backgroundColor: '#CF0A2C', aliases: ['huaweicloud', '华为云'] },
  { key: ServiceIconKey.BAIDU_AI_CLOUD, backgroundColor: '#2932E1', aliases: ['baiduaicloud', 'baiducloud', '百度智能云', '百度云'] },
  { key: ServiceIconKey.VOLCANO_ENGINE, backgroundColor: '#1664FF', aliases: ['volcanoengine', 'volcengine', '火山引擎'] },
  { key: ServiceIconKey.GOOGLE, backgroundColor: '#4285F4', aliases: ['google', 'googleworkspace', 'googlecom'] },
  { key: ServiceIconKey.MICROSOFT, backgroundColor: '#5E5E5E', aliases: ['microsoft', 'microsoftentra', 'microsoftentraid', 'entra', 'azure', 'office365', 'microsoft365'] },
  { key: ServiceIconKey.GITHUB, backgroundColor: '#24292F', aliases: ['github', 'githubcom', 'githubenterprise'] },
  { key: ServiceIconKey.APPLE, backgroundColor: '#111111', aliases: ['apple', 'appleid'] },
  { key: ServiceIconKey.AWS, backgroundColor: '#232F3E', aliases: ['aws', 'amazonwebservices', 'amazonaws'] },
  { key: ServiceIconKey.CLOUDFLARE, backgroundColor: '#F38020', aliases: ['cloudflare'] },
  { key: ServiceIconKey.STEAM, backgroundColor: '#1B2838', aliases: ['steam'] },
  { key: ServiceIconKey.DISCORD, backgroundColor: '#5865F2', aliases: ['discord'] },
  { key: ServiceIconKey.DROPBOX, backgroundColor: '#0061FF', aliases: ['dropbox'] },
  { key: ServiceIconKey.SLACK, backgroundColor: '#611F69', aliases: ['slack'] },
  { key: ServiceIconKey.BITWARDEN, backgroundColor: '#175DDC', aliases: ['bitwarden'] },
  { key: ServiceIconKey.ONE_PASSWORD, backgroundColor: '#0572EC', aliases: ['1password', 'onepassword'] },
  { key: ServiceIconKey.GITLAB, backgroundColor: '#FC6D26', aliases: ['gitlab', 'gitlabcom'] },
  { key: ServiceIconKey.PROTON, backgroundColor: '#6D4AFF', aliases: ['proton', 'protonmail'] },
  { key: ServiceIconKey.OPENAI, backgroundColor: '#10A37F', aliases: ['openai', 'chatgpt'] }
];

function normalizeServiceIssuer(issuer: string): string {
  return issuer.trim().toLowerCase().replace(/[\s._-]+/g, '');
}

export function resolveServiceIcon(issuer: string): ServiceIconMatch | undefined {
  const normalized: string = normalizeServiceIssuer(issuer);
  if (normalized.length === 0) {
    return undefined;
  }
  for (let index: number = 0; index < SERVICE_ICONS.length; index += 1) {
    const definition: ServiceIconDefinition = SERVICE_ICONS[index];
    if (definition.aliases.includes(normalized)) {
      return { key: definition.key, backgroundColor: definition.backgroundColor };
    }
  }
  return undefined;
}

export function serviceInitial(issuer: string): string {
  const trimmed: string = issuer.trim();
  return trimmed.length === 0 ? '?' : trimmed.substring(0, 1).toUpperCase();
}
