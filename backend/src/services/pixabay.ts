import { config } from '../config/index.js';
import OpenAI from 'openai';

const PIXABAY_API_URL = 'https://pixabay.com/api/';

// Initialize Groq client (uses OpenAI-compatible API)
const hasGroq = config.groq?.apiKey && config.groq.apiKey.length > 10;
const groq = hasGroq ? new OpenAI({
  apiKey: config.groq.apiKey,
  baseURL: 'https://api.groq.com/openai/v1',
}) : null;

/**
 * Detect if text contains Hindi (Devanagari script)
 */
export function isHindiText(text: string): boolean {
  // Devanagari Unicode range: \u0900-\u097F
  const devanagariPattern = /[\u0900-\u097F]/;
  return devanagariPattern.test(text);
}

/**
 * Translate Hindi text to English using Groq
 */
export async function translateHindiToEnglish(hindiText: string): Promise<string> {
  if (!groq) {
    console.warn('Groq not configured, returning original text');
    return hindiText;
  }
  
  try {
    const response = await groq.chat.completions.create({
      model: 'llama-3.1-8b-instant',
      messages: [
        {
          role: 'system',
          content: 'You are a translator. Translate the given Hindi text to English. Return ONLY the English translation, nothing else.',
        },
        {
          role: 'user',
          content: hindiText,
        },
      ],
      temperature: 0.1,
      max_tokens: 200,
    });
    
    const translation = response.choices[0]?.message?.content?.trim();
    return translation || hindiText;
  } catch (error) {
    console.error('Error translating Hindi to English:', error);
    return hindiText;
  }
}

// Keywords to ignore when extracting topic keywords
const STOP_WORDS = new Set([
  'should', 'could', 'would', 'will', 'can', 'may', 'might',
  'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
  'have', 'has', 'had', 'do', 'does', 'did', 'done',
  'and', 'or', 'but', 'if', 'then', 'else', 'when', 'where', 'why', 'how',
  'all', 'each', 'every', 'both', 'few', 'more', 'most', 'other', 'some', 'such',
  'no', 'nor', 'not', 'only', 'own', 'same', 'so', 'than', 'too', 'very',
  'just', 'also', 'now', 'here', 'there', 'what', 'which', 'who', 'whom',
  'this', 'that', 'these', 'those', 'am', 'at', 'by', 'for', 'from',
  'in', 'into', 'of', 'on', 'to', 'up', 'with', 'about', 'against',
  'between', 'through', 'during', 'before', 'after', 'above', 'below',
  'india', 'indian', 'us', 'usa', 'america', 'american', 'country', 'countries',
  'people', 'person', 'government', 'need', 'needs', 'really', 'actually',
  'make', 'made', 'get', 'got', 'take', 'taken', 'give', 'given',
  'good', 'bad', 'best', 'worst', 'better', 'worse', 'new', 'old',
  'first', 'last', 'long', 'great', 'little', 'own', 'right', 'wrong',
  'high', 'low', 'small', 'large', 'big', 'different', 'important',
  'क्या', 'है', 'हैं', 'के', 'की', 'को', 'में', 'से', 'पर', 'और', 'या',
  'एक', 'यह', 'वह', 'जो', 'कि', 'लिए', 'साथ', 'होना', 'करना', 'भारत',
]);

// High-value keywords mapped to diverse search terms
// Each keyword has multiple search variations for diversity
const PRIORITY_KEYWORDS: Record<string, string[]> = {
  // Sports - diverse terms
  'cricket': ['cricket bat ball', 'cricket stadium', 'cricket player'],
  'ipl': ['cricket trophy', 'cricket match', 'sports stadium'],
  'football': ['football soccer ball', 'soccer player', 'football stadium'],
  'soccer': ['soccer ball goal', 'soccer match', 'football player'],
  'basketball': ['basketball hoop', 'basketball player', 'basketball court'],
  'hockey': ['hockey stick puck', 'ice hockey', 'field hockey'],
  'tennis': ['tennis racket ball', 'tennis court', 'tennis player'],
  'olympics': ['olympics medal', 'olympic rings', 'sports champion'],
  'athlete': ['athlete running', 'sports fitness', 'marathon runner'],
  'sports': ['sports equipment', 'athletics', 'fitness exercise'],
  'injury': ['medical bandage', 'hospital care', 'health treatment'],
  
  // Technology - diverse terms
  'ai': ['artificial intelligence', 'robot technology', 'machine learning'],
  'robot': ['robot machine', 'automation technology', 'futuristic robot'],
  'technology': ['technology innovation', 'digital future', 'tech devices'],
  'social media': ['social network', 'online community', 'digital communication'],
  'influencer': ['online personality', 'social media star', 'digital marketing'],
  'cyber': ['cybersecurity', 'digital security', 'network protection'],
  'hacking': ['computer security', 'cyber attack', 'digital crime'],
  'bitcoin': ['cryptocurrency', 'digital currency', 'blockchain'],
  'crypto': ['cryptocurrency coin', 'digital money', 'blockchain technology'],
  'smartphone': ['mobile phone', 'smartphone device', 'digital communication'],
  'internet': ['world wide web', 'online connection', 'digital network'],
  'privacy': ['data protection', 'security lock', 'personal privacy'],
  'data': ['digital data', 'information technology', 'database'],
  
  // Politics & Government - diverse terms
  'election': ['voting ballot', 'election campaign', 'democracy vote'],
  'vote': ['ballot box', 'voting rights', 'election poll'],
  'democracy': ['democratic government', 'freedom rights', 'political system'],
  'parliament': ['government building', 'legislative assembly', 'politics'],
  'law': ['justice scales', 'legal court', 'law books'],
  'court': ['courtroom justice', 'legal gavel', 'judge law'],
  'police': ['law enforcement', 'security officer', 'public safety'],
  'military': ['armed forces', 'soldier army', 'defense military'],
  'war': ['conflict battle', 'peace war', 'military combat'],
  'peace': ['peace dove', 'harmony unity', 'world peace'],
  'policy': ['government policy', 'political decision', 'public administration'],
  'regulation': ['rules compliance', 'legal regulation', 'government control'],
  
  // Business & Finance - diverse terms
  'stock': ['stock market graph', 'trading finance', 'investment chart'],
  'market': ['financial market', 'business trading', 'economy graph'],
  'economy': ['economic growth', 'finance money', 'business success'],
  'tax': ['tax money', 'financial documents', 'government revenue'],
  'bank': ['banking finance', 'money savings', 'financial institution'],
  'banking': ['bank building', 'financial services', 'money transfer'],
  'foreclosure': ['house sale', 'property auction', 'real estate'],
  'investment': ['investment growth', 'financial planning', 'money savings'],
  'startup': ['business startup', 'entrepreneur', 'innovation company'],
  'manufacturing': ['factory industry', 'production line', 'industrial manufacturing'],
  'energy': ['power energy', 'electricity', 'renewable energy'],
  'oil': ['petroleum industry', 'oil barrel', 'energy fuel'],
  'brand': ['brand marketing', 'company logo', 'business identity'],
  'company': ['corporate business', 'office building', 'business meeting'],
  'aggressive': ['intense competition', 'business strategy', 'competitive market'],
  
  // Entertainment & Media - diverse terms
  'movie': ['cinema film', 'movie theater', 'film production'],
  'film': ['filmmaking camera', 'movie reel', 'cinema entertainment'],
  'celebrity': ['famous star', 'entertainment celebrity', 'media personality'],
  'endorsement': ['advertising promotion', 'brand ambassador', 'marketing campaign'],
  'music': ['musical instrument', 'concert performance', 'music notes'],
  'bollywood': ['indian cinema', 'dance performance', 'film industry'],
  'gaming': ['video game controller', 'esports gaming', 'game console'],
  'netflix': ['streaming service', 'television entertainment', 'online video'],
  'release': ['product launch', 'new release', 'premiere event'],
  'strategic': ['business strategy', 'planning chess', 'tactical decision'],
  
  // Social Issues - diverse terms
  'marriage': ['wedding ceremony', 'couple love', 'marriage celebration'],
  'wedding': ['bride groom', 'wedding rings', 'marriage ceremony'],
  'education': ['school learning', 'education books', 'student classroom'],
  'school': ['classroom education', 'student learning', 'academic school'],
  'health': ['medical healthcare', 'wellness health', 'doctor patient'],
  'hospital': ['medical facility', 'healthcare hospital', 'doctor nurse'],
  'doctor': ['medical professional', 'healthcare doctor', 'physician'],
  'climate': ['climate change', 'environment nature', 'global warming'],
  'pollution': ['environmental pollution', 'air quality', 'waste management'],
  'environment': ['nature conservation', 'green environment', 'ecology'],
  'farmer': ['agriculture farming', 'rural farmer', 'crop field'],
  'agriculture': ['farming tractor', 'crop harvest', 'rural agriculture'],
  'women': ['female empowerment', 'women rights', 'gender equality'],
  'revive': ['recovery growth', 'renewal rebirth', 'restoration'],
  'struggling': ['challenge difficulty', 'business struggle', 'financial trouble'],
  
  // Public discourse & debate topics
  'criticize': ['public opinion', 'discussion debate', 'speech microphone'],
  'criticism': ['feedback review', 'public speaking', 'commentary opinion'],
  'public': ['public speaker', 'community people', 'crowd audience'],
  'figure': ['leadership speaker', 'famous person', 'public figure'],
  'prioritize': ['priority decision', 'choice selection', 'balance scale'],
  'economic': ['economy finance', 'business growth', 'money investment'],
  'growth': ['growth chart', 'business success', 'plant growing'],
  'trade': ['international trade', 'business handshake', 'global commerce'],
  'deal': ['business agreement', 'handshake deal', 'contract signing'],
  'interest': ['financial interest', 'benefit advantage', 'money profit'],
  'merger': ['business merger', 'company acquisition', 'corporate deal'],
  'acquisition': ['business takeover', 'corporate merger', 'company buyout'],
  'consumer': ['shopping customer', 'retail buyer', 'consumer market'],
  'benefit': ['advantage profit', 'success reward', 'positive outcome'],
  
  // Space & Science
  'mars': ['mars planet', 'space exploration', 'astronaut space'],
  'space': ['outer space', 'astronaut rocket', 'galaxy stars'],
  'colonize': ['space colony', 'future settlement', 'mars colonization'],
  'science': ['scientific research', 'laboratory experiment', 'science discovery'],
  'research': ['research laboratory', 'scientific study', 'investigation analysis'],
  
  // More common debate terms
  'ban': ['prohibition sign', 'restricted forbidden', 'stop ban'],
  'allow': ['permission granted', 'approval checkmark', 'access allowed'],
  'government': ['government building', 'politics administration', 'public office'],
  'freedom': ['liberty freedom', 'independence flag', 'free speech'],
  'rights': ['human rights', 'civil rights', 'justice equality'],
  'justice': ['justice scales', 'court law', 'fairness equality'],
  'equality': ['equal rights', 'balance fairness', 'diversity inclusion'],
  'future': ['future technology', 'tomorrow vision', 'forward progress'],
  'problem': ['problem solving', 'challenge solution', 'puzzle thinking'],
  'solution': ['solution idea', 'problem solving', 'lightbulb innovation'],
};

/**
 * Extract the most relevant keyword from a room title for image search
 * Returns a random search term from matched keywords for diversity
 */
export function extractKeyword(title: string): string {
  const lowerTitle = title.toLowerCase();
  
  // First, check for priority keywords (multi-word phrases first)
  const sortedPriorities = Object.entries(PRIORITY_KEYWORDS)
    .sort((a, b) => b[0].length - a[0].length);
  
  for (const [keyword, searchTerms] of sortedPriorities) {
    if (lowerTitle.includes(keyword)) {
      // Pick a random search term for diversity
      const randomIndex = Math.floor(Math.random() * searchTerms.length);
      return searchTerms[randomIndex];
    }
  }
  
  // Fall back to extracting meaningful words from title
  const words = title
    .toLowerCase()
    .replace(/[^\w\s]/g, '') // Remove punctuation
    .split(/\s+/)
    .filter(word => word.length > 3 && !STOP_WORDS.has(word));
  
  // Use the longest word as search term (most specific)
  if (words.length > 0) {
    const sortedWords = words.sort((a, b) => b.length - a.length);
    // Return top word with some variation
    return sortedWords[0];
  }
  
  // Final fallback - generic but varied terms
  const fallbacks = ['discussion forum', 'debate conversation', 'talk speech', 'opinion idea'];
  return fallbacks[Math.floor(Math.random() * fallbacks.length)];
}

interface PixabayImage {
  id: number;
  webformatURL: string;
  largeImageURL: string;
  tags: string;
}

interface PixabayResponse {
  total: number;
  totalHits: number;
  hits: PixabayImage[];
}

/**
 * Simple string hash function for deterministic image selection
 */
function hashString(str: string): number {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash; // Convert to 32-bit integer
  }
  return Math.abs(hash);
}

/**
 * Search Pixabay for illustrations matching a keyword
 */
export async function searchIllustrations(
  keyword: string,
  count: number = 20
): Promise<string[]> {
  const apiKey = config.pixabay?.apiKey;
  
  if (!apiKey) {
    console.warn('Pixabay API key not configured');
    return [];
  }
  
  try {
    // Request many results for diversity (removed editors_choice - too restrictive)
    const params = new URLSearchParams({
      key: apiKey,
      q: `${keyword} illustration`,
      image_type: 'illustration',
      orientation: 'horizontal',
      per_page: Math.max(count, 30).toString(), // Get 30+ for maximum diversity
      safesearch: 'true',
    });
    
    const response = await fetch(`${PIXABAY_API_URL}?${params}`);
    
    if (!response.ok) {
      console.error(`Pixabay API error: ${response.status}`);
      return [];
    }
    
    const data = await response.json() as PixabayResponse;
    
    // Return the webformat URLs (640px wide, good for thumbnails)
    return data.hits.map(hit => hit.webformatURL);
  } catch (error) {
    console.error('Error fetching from Pixabay:', error);
    return [];
  }
}

/**
 * Get a single illustration URL for a room title
 * Handles both English and Hindi titles (translates Hindi first)
 * Uses title hash for deterministic but unique image selection per room
 */
export async function getIllustrationForTitle(title: string): Promise<string | null> {
  let textForKeyword = title;
  
  // If title is in Hindi, translate to English first
  if (isHindiText(title)) {
    console.log(`Detected Hindi title, translating: ${title.substring(0, 50)}...`);
    textForKeyword = await translateHindiToEnglish(title);
    console.log(`Translated to: ${textForKeyword.substring(0, 50)}...`);
  }
  
  const keyword = extractKeyword(textForKeyword);
  console.log(`Searching Pixabay for keyword: ${keyword} (from title: ${title.substring(0, 40)}...)`);
  
  // Get many images for diversity
  let images = await searchIllustrations(keyword, 30);
  
  // If no results, try a fallback search with just the main word
  if (images.length === 0) {
    const fallbackKeyword = keyword.split(' ')[0];
    console.log(`No results for "${keyword}", trying fallback: ${fallbackKeyword}`);
    images = await searchIllustrations(fallbackKeyword, 30);
  }
  
  // If still no results, try category-based fallback
  if (images.length === 0) {
    console.log(`No results for fallback, trying generic "concept idea"`);
    images = await searchIllustrations('concept idea abstract', 30);
  }
  
  if (images.length === 0) {
    return null;
  }
  
  // Use title hash for DETERMINISTIC selection - same title always gets same image
  // but different titles get different images from the pool
  const titleHash = hashString(title);
  const selectedIndex = titleHash % images.length;
  
  console.log(`Selected image ${selectedIndex + 1}/${images.length} for title hash ${titleHash}`);
  
  return images[selectedIndex];
}

// Cache for illustration URLs to avoid repeated API calls
const illustrationCache = new Map<string, { url: string; timestamp: number }>();
const CACHE_TTL = 24 * 60 * 60 * 1000; // 24 hours

/**
 * Get illustration with caching
 */
export async function getCachedIllustration(title: string): Promise<string | null> {
  const keyword = extractKeyword(title);
  const cached = illustrationCache.get(keyword);
  
  if (cached && Date.now() - cached.timestamp < CACHE_TTL) {
    return cached.url;
  }
  
  const url = await getIllustrationForTitle(title);
  
  if (url) {
    illustrationCache.set(keyword, { url, timestamp: Date.now() });
  }
  
  return url;
}
