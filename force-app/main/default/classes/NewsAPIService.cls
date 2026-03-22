/**
 * Service class to interact with the NewsAPI for fetching top headlines
 * @see https://newsapi.org/docs/endpoints/top-headlines
 */
public with sharing class NewsAPIService {
    private static final String API_NAMED_CREDENTIAL = 'callout:NewsAPI';
    private static final String API_ENDPOINT = '/v2/top-headlines';
    private static final Integer PAGE_SIZE = 20;
    private static final Integer CALLOUT_TIMEOUT_MS = 120000;

    private static final Set<String> VALID_CATEGORIES = new Set<String>{
        'business',
        'entertainment',
        'general',
        'health',
        'science',
        'sports',
        'technology'
    };

    /**
     * Fetches top headlines for a specified category with pagination support.
     * Uses a fixed page size ({@link #PAGE_SIZE}) on every request.
     *
     * @param category The news category (business, entertainment, general, health, science, sports, technology)
     * @param page Page number for pagination (values less than 1 are treated as 1)
     * @return NewsAPIResponse The wrapper object containing the API response
     */
    public static NewsAPIResponse getTopHeadlinesByCategory(String category, Integer page) {
        if (String.isBlank(category)) {
            throw new NewsAPIException('Category is required.');
        }
        String normalizedCategory = category.trim().toLowerCase();
        if (!VALID_CATEGORIES.contains(normalizedCategory)) {
            throw new NewsAPIException('Invalid category: ' + category);
        }

        Integer effectivePage = (page == null || page < 1) ? 1 : page;
        String query =
            'category=' +
            EncodingUtil.urlEncode(normalizedCategory, 'UTF-8') +
            '&page=' +
            effectivePage +
            '&pageSize=' +
            PAGE_SIZE;

        String endpoint = API_NAMED_CREDENTIAL + API_ENDPOINT + '?' + query;
        HttpResponse res = makeCallout(endpoint);

        if (res.getStatusCode() != 200) {
            throw new NewsAPIException(
                'Request failed with status ' + res.getStatusCode() + ': ' + res.getBody()
            );
        }

        NewsAPIResponse parsed = parseResponse(res.getBody());
        if (parsed != null && parsed.status == 'error') {
            String detail = String.isNotBlank(parsed.message) ? parsed.message : 'Unknown NewsAPI error';
            throw new NewsAPIException(detail);
        }
        return parsed;
    }

    /**
     * @param endpoint Full callout URL (named credential + path + query)
     */
    private static HttpResponse makeCallout(String endpoint) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setTimeout(CALLOUT_TIMEOUT_MS);

        try {
            return new Http().send(req);
        } catch (System.CalloutException e) {
            throw new NewsAPIException('Callout failed: ' + e.getMessage());
        }
    }

    private static NewsAPIResponse parseResponse(String jsonResponse) {
        if (String.isBlank(jsonResponse)) {
            throw new NewsAPIException('Empty response body from NewsAPI.');
        }
        try {
            return NewsAPIResponse.parse(jsonResponse);
        } catch (Exception e) {
            throw new NewsAPIException('Could not parse NewsAPI response: ' + e.getMessage());
        }
    }

    /**
     * Custom exception class for NewsAPI errors
     */
    public class NewsAPIException extends Exception {
    }
}
