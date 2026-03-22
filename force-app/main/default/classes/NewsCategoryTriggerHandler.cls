/**
 * Handler class for NewsCategoryTrigger
 */
public with sharing class NewsCategoryTriggerHandler {
    /**
     * Handles after insert events for News_Category__c
     * Uses Queueable for callouts when Sync__c is true
     * @param newRecords List of newly inserted News_Category__c records
     */
    public static void handleInsert(List<News_Category__c> newRecords) {
        List<News_Category__c> toSync = new List<News_Category__c>();
        for (News_Category__c cat : newRecords) {
            if (cat.Sync__c == true) {
                toSync.add(cat);
            }
        }
        syncCategoriesWithQueueable(toSync);
    }

    /**
     * Handles after update events for News_Category__c
     * Uses Queueable Apex for callouts when Sync__c is true
     * @param newRecords List of updated News_Category__c records
     * @param oldMap Map of old record states
     */
    public static void handleUpdate(List<News_Category__c> newRecords, Map<Id, News_Category__c> oldMap) {
        List<News_Category__c> toSync = new List<News_Category__c>();
        for (News_Category__c cat : newRecords) {
            News_Category__c oldCat = oldMap.get(cat.Id);
            if (oldCat != null && oldCat.Sync__c == false && cat.Sync__c == true) {
                toSync.add(cat);
            }
        }
        syncCategoriesWithQueueable(toSync);
    }

    /**
     * Queueable method to sync categories using the NewsAPI
     * @param categoriesToSync List of News_Category__c records to sync
     */
    private static void syncCategoriesWithQueueable(List<News_Category__c> categoriesToSync) {
        if (categoriesToSync.isEmpty()) {
            return;
        }
        for (News_Category__c cat : categoriesToSync) {
            System.enqueueJob(new NewsCategoryQueueable(cat, 1));
        }
    }
}
