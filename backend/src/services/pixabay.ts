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

// High-value keywords that should be prioritized
const PRIORITY_KEYWORDS: Record<string, string> = {
  // Sports
  'cricket': 'cricket player',
  'ipl': 'cricket',
  'football': 'football soccer',
  'soccer': 'football soccer',
  'basketball': 'basketball',
  'hockey': 'hockey',
  'tennis': 'tennis',
  'olympics': 'olympics medal',
  'athlete': 'athlete running',
  'sports': 'sports',
  
  // Technology
  'ai': 'artificial intelligence robot',
  'robot': 'robot',
  'social media': 'social media phone',
  'influencer': 'influencer phone',
  'cyber': 'cybersecurity hacker',
  'hacking': 'cybersecurity hacker',
  'bitcoin': 'bitcoin cryptocurrency',
  'crypto': 'cryptocurrency',
  'smartphone': 'smartphone mobile',
  'internet': 'internet connection',
  
  // Politics
  'election': 'election voting',
  'vote': 'voting ballot',
  'democracy': 'democracy vote',
  'parliament': 'parliament government',
  'law': 'law justice',
  'court': 'court justice',
  'police': 'police officer',
  'military': 'military soldier',
  'war': 'war conflict',
  'peace': 'peace dove',
  
  // Business
  'stock': 'stock market chart',
  'market': 'stock market',
  'economy': 'economy growth',
  'tax': 'tax money',
  'bank': 'bank money',
  'investment': 'investment growth',
  'startup': 'startup business',
  'manufacturing': 'factory manufacturing',
  'energy': 'energy power',
  'oil': 'oil petroleum',
  
  // Entertainment
  'movie': 'movie cinema',
  'film': 'film cinema',
  'music': 'music concert',
  'bollywood': 'bollywood dance',
  'gaming': 'gaming controller',
  'netflix': 'streaming television',
  
  // Social
  'marriage': 'wedding couple',
  'education': 'education school',
  'health': 'health medical',
  'hospital': 'hospital medical',
  'climate': 'climate environment',
  'pollution': 'pollution environment',
  'farmer': 'farmer agriculture',
  'women': 'women empowerment',
};

/**
 * Extract the most relevant keyword from a room title for image search
 */
export function extractKeyword(title: string): string {
  const lowerTitle = title.toLowerCase();
  
  // First, check for priority keywords (multi-word phrases first)
  const sortedPriorities = Object.entries(PRIORITY_KEYWORDS)
    .sort((a, b) => b[0].length - a[0].length);
  
  for (const [keyword, searchTerm] of sortedPriorities) {
    if (lowerTitle.includes(keyword)) {
      return searchTerm;
    }
  }
  
  // Fall back to extracting the most meaningful word
  const words = title
    .toLowerCase()
    .replace(/[^\w\s]/g, '') // Remove punctuation
    .split(/\s+/)
    .filter(word => word.length > 3 && !STOP_WORDS.has(word));
  
  // Return the longest word (often the most specific/meaningful)
  if (words.length > 0) {
    return words.sort((a, b) => b.length - a.length)[0];
  }
  
  return 'discussion debate';
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
 * Search Pixabay for illustrations matching a keyword
 */
export async function searchIllustrations(
  keyword: string,
  count: number = 5
): Promise<string[]> {
  const apiKey = config.pixabay?.apiKey;
  
  if (!apiKey) {
    console.warn('Pixabay API key not configured');
    return [];
  }
  
  try {
    const params = new URLSearchParams({
      key: apiKey,
      q: `simple ${keyword} illustration`,
      image_type: 'illustration',
      orientation: 'horizontal',
      per_page: count.toString(),
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
  console.log(`Searching Pixabay for keyword: ${keyword}`);
  
  const images = await searchIllustrations(keyword, 3);
  
  if (images.length === 0) {
    return null;
  }
  
  // Return a random image from the results for variety
  return images[Math.floor(Math.random() * images.length)];
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
