#import <Foundation/Foundation.h>
#import <GoogleMobileAds/GoogleMobileAds.h>
#import "SinkCity-Swift.h"
#include "core/config/engine.h"
#include "core/object/class_db.h"
#include "core/variant/dictionary.h"

static NSString *ns(const String &value) { return [NSString stringWithUTF8String:value.utf8().get_data()]; }
static String gs(id value) { return [value isKindOfClass:NSString.class] ? String([(NSString *)value UTF8String]) : String(); }

class HoleFeastAds : public Object {
    GDCLASS(HoleFeastAds, Object);
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("sink_city_rewarded_protocol_version"), &HoleFeastAds::protocol_version);
        ClassDB::bind_method(D_METHOD("initialize"), &HoleFeastAds::initialize);
        ClassDB::bind_method(D_METHOD("rewarded_available"), &HoleFeastAds::available);
        ClassDB::bind_method(D_METHOD("retry_rewarded"), &HoleFeastAds::retry);
        ClassDB::bind_method(D_METHOD("show_rewarded", "request_id"), &HoleFeastAds::show);
        ClassDB::bind_method(D_METHOD("poll_events"), &HoleFeastAds::poll);
        ClassDB::bind_method(D_METHOD("privacy_options_required"), &HoleFeastAds::privacy_required);
        ClassDB::bind_method(D_METHOD("show_privacy_options"), &HoleFeastAds::privacy_options);
        ADD_SIGNAL(MethodInfo("rewarded_earned", PropertyInfo(Variant::STRING, "request_id")));
        ADD_SIGNAL(MethodInfo("rewarded_closed", PropertyInfo(Variant::STRING, "request_id")));
        ADD_SIGNAL(MethodInfo("rewarded_failed", PropertyInfo(Variant::STRING, "request_id"), PropertyInfo(Variant::STRING, "message")));
        ADD_SIGNAL(MethodInfo("availability_changed"));
    }
public:
    int protocol_version() { return 1; }
    void initialize() { [[HoleFeastServices shared] initializeAds]; }
    bool available() { return [[HoleFeastServices shared] rewardedAvailable]; }
    void retry() { [[HoleFeastServices shared] retryRewarded]; }
    bool show(const String &identity) { return [[HoleFeastServices shared] showRewarded:ns(identity)]; }
    bool privacy_required() { return [[HoleFeastServices shared] privacyOptionsRequired]; }
    bool privacy_options() { return [[HoleFeastServices shared] showPrivacyOptions]; }
    void poll() {
        for (NSDictionary *event in [[HoleFeastServices shared] drainEvents:@"ads"]) {
            String name = gs(event[@"name"]), identity = gs(event[@"request_id"]);
            if (name == "rewarded_earned" || name == "rewarded_closed") emit_signal(name, identity);
            else if (name == "rewarded_failed") emit_signal(name, identity, gs(event[@"message"]));
            else if (name == "availability_changed") emit_signal(name);
        }
    }
};

class HoleFeastCommerce : public Object {
    GDCLASS(HoleFeastCommerce, Object);
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("sink_city_commerce_protocol_version"), &HoleFeastCommerce::protocol_version);
        ClassDB::bind_method(D_METHOD("initialize"), &HoleFeastCommerce::initialize);
        ClassDB::bind_method(D_METHOD("purchases_available"), &HoleFeastCommerce::available);
        ClassDB::bind_method(D_METHOD("request_products", "ids"), &HoleFeastCommerce::products);
        ClassDB::bind_method(D_METHOD("purchase", "product_id", "request_id"), &HoleFeastCommerce::purchase);
        ClassDB::bind_method(D_METHOD("acknowledge", "transaction_id"), &HoleFeastCommerce::acknowledge);
        ClassDB::bind_method(D_METHOD("poll_events"), &HoleFeastCommerce::poll);
        ADD_SIGNAL(MethodInfo("products_received", PropertyInfo(Variant::ARRAY, "products")));
        ADD_SIGNAL(MethodInfo("purchase_verified", PropertyInfo(Variant::STRING, "transaction_id"), PropertyInfo(Variant::STRING, "product_id"), PropertyInfo(Variant::STRING, "request_id")));
        ADD_SIGNAL(MethodInfo("purchase_failed", PropertyInfo(Variant::STRING, "request_id"), PropertyInfo(Variant::STRING, "message")));
        ADD_SIGNAL(MethodInfo("purchase_pending", PropertyInfo(Variant::STRING, "request_id")));
        ADD_SIGNAL(MethodInfo("availability_changed"));
    }
public:
    int protocol_version() { return 1; }
    void initialize() { [[HoleFeastServices shared] initializeCommerce]; }
    bool available() { return [[HoleFeastServices shared] purchasesAvailable]; }
    void products(const PackedStringArray &identifiers) {
        NSMutableArray<NSString *> *values = [NSMutableArray array];
        for (int i = 0; i < identifiers.size(); i++) [values addObject:ns(identifiers[i])];
        [[HoleFeastServices shared] requestProducts:values];
    }
    bool purchase(const String &product, const String &request) { return [[HoleFeastServices shared] purchase:ns(product) requestID:ns(request)]; }
    bool acknowledge(const String &identity) { return [[HoleFeastServices shared] acknowledge:ns(identity)]; }
    void poll() {
        for (NSDictionary *event in [[HoleFeastServices shared] drainEvents:@"commerce"]) {
            String name = gs(event[@"name"]);
            if (name == "products_received") {
                Array values;
                for (NSDictionary *item in event[@"products"]) {
                    Dictionary product;
                    product["product_id"] = gs(item[@"product_id"]);
                    product["localized_price"] = gs(item[@"localized_price"]);
                    values.push_back(product);
                }
                emit_signal(name, values);
            } else if (name == "purchase_verified") emit_signal(name, gs(event[@"transaction_id"]), gs(event[@"product_id"]), gs(event[@"request_id"]));
            else if (name == "purchase_failed") emit_signal(name, gs(event[@"request_id"]), gs(event[@"message"]));
            else if (name == "purchase_pending") emit_signal(name, gs(event[@"request_id"]));
            else if (name == "availability_changed") emit_signal(name);
        }
    }
};

class HoleFeastFeedback : public Object {
    GDCLASS(HoleFeastFeedback, Object);
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("play_swallow_haptic", "amplitude"), &HoleFeastFeedback::play);
    }
public:
    void play(double amplitude) { [[HoleFeastServices shared] playSwallowHaptic:amplitude]; }
};

static HoleFeastAds *ads = nullptr;
static HoleFeastCommerce *commerce = nullptr;
static HoleFeastFeedback *feedback = nullptr;
void hole_feast_services_initialize() {
    ClassDB::register_class<HoleFeastAds>(); ClassDB::register_class<HoleFeastCommerce>();
    ClassDB::register_class<HoleFeastFeedback>();
    ads = memnew(HoleFeastAds); commerce = memnew(HoleFeastCommerce);
    feedback = memnew(HoleFeastFeedback);
    Engine::get_singleton()->add_singleton(Engine::Singleton("GoogleMobileAds", ads));
    Engine::get_singleton()->add_singleton(Engine::Singleton("SinkCityCommerce", commerce));
    Engine::get_singleton()->add_singleton(Engine::Singleton("HoleFeastFeedback", feedback));
}
void hole_feast_services_deinitialize() {
    Engine::get_singleton()->remove_singleton("GoogleMobileAds");
    Engine::get_singleton()->remove_singleton("SinkCityCommerce");
    Engine::get_singleton()->remove_singleton("HoleFeastFeedback");
    memdelete(ads); memdelete(commerce); ads = nullptr; commerce = nullptr;
    memdelete(feedback); feedback = nullptr;
}
