#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <mach-o/dyld.h>
#include <cstring>
#include "dobby.h" // FILL: положи dobby.h и libdobby.a в проект, линкуй с -ldobby

// --- ЧАСТЬ 1: ГЛОБАЛЬНЫЕ ФЛАГИ И ЛОГИКА ВЗЛОМА ПАМЯТИ ---

BOOL godModeEnabled = NO;
BOOL infiniteTimeEnabled = NO;
BOOL scoreMultiplierEnabled = NO;
BOOL moneyHackEnabled = NO;

// Динамический поиск базового адреса UnityFramework для работы через сайдлоад
uintptr_t get_UnityFramework_BaseAddress() {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "UnityFramework")) {
            return (uintptr_t)_dyld_get_image_header(i);
        }
    }
    return (uintptr_t)_dyld_get_image_header(0);
}

// Указатели на оригинальные функции игры для вызова внутри хуков
void (*old_HR_PlayerHandler_OnCollisionEnter)(void* instance, void* collision);
void (*old_HR_PlayerHandler_Update)(void* instance);
void (*old_GamePlayScoresManager_Update)(void* instance);
void (*old_HR_MainMenuHandler_Start)(void* instance);

// 1. Модуль: Бессмертие (Блокировка урона при аварии трафика)
void new_HR_PlayerHandler_OnCollisionEnter(void* instance, void* collision) {
    if (godModeEnabled) {
        return;
    }
    if (old_HR_PlayerHandler_OnCollisionEnter) {
        old_HR_PlayerHandler_OnCollisionEnter(instance, collision);
    }
}

// 2. Модуль: Заморозка времени гонки на 99 секундах
void new_HR_PlayerHandler_Update(void* instance) {
    if (old_HR_PlayerHandler_Update) {
        old_HR_PlayerHandler_Update(instance);
    }
    if (instance != nullptr && infiniteTimeEnabled) {
        *(float*)((uintptr_t)instance + 0x48) = 99.0f;
    }
}

// 3. Модуль: Безумный множитель очков x500
void new_GamePlayScoresManager_Update(void* instance) {
    if (old_GamePlayScoresManager_Update) {
        old_GamePlayScoresManager_Update(instance);
    }
    if (instance != nullptr && scoreMultiplierEnabled) {
        *(float*)((uintptr_t)instance + 0x4C) = 500.0f;
    }
}

// 4. Модуль: Разблокировка 1,000,000$ (Дебаг-переключатель)
void new_HR_MainMenuHandler_Start(void* instance) {
    if (old_HR_MainMenuHandler_Start) {
        old_HR_MainMenuHandler_Start(instance);
    }
    if (moneyHackEnabled) {
        uintptr_t unityBase = get_UnityFramework_BaseAddress();
        void* (*HR_HighwayRacerProperties_get_Instance)() = (void*(*)())(unityBase + 0x3E37DA8);
        void* propertiesAsset = HR_HighwayRacerProperties_get_Instance();
        if (propertiesAsset != nullptr) {
            *(bool*)((uintptr_t)propertiesAsset + 0x50) = true;
        }
    }
}

// Установка хуков (RVA от базы UnityFramework)
static void install_hooks() {
    uintptr_t base = get_UnityFramework_BaseAddress();

    DobbyHook((void*)(base + 0x3E452A4),
              (void*)new_HR_PlayerHandler_OnCollisionEnter,
              (void**)&old_HR_PlayerHandler_OnCollisionEnter);

    DobbyHook((void*)(base + 0x3E443E0),
              (void*)new_HR_PlayerHandler_Update,
              (void**)&old_HR_PlayerHandler_Update);

    DobbyHook((void*)(base + 0x3BA37D8),
              (void*)new_GamePlayScoresManager_Update,
              (void**)&old_GamePlayScoresManager_Update);

    DobbyHook((void*)(base + 0x3E3CF58),
              (void*)new_HR_MainMenuHandler_Start,
              (void**)&old_HR_MainMenuHandler_Start);
}

// --- ЧАСТЬ 2: ГРАФИЧЕСКИЙ ИНТЕРФЕЙС МЕНЮ В КОСМИЧЕСКОМ СТИЛЕ ---

@interface CosmicMenuWindow : UIWindow
@property (nonatomic, strong) UIView *menuView;
@property (nonatomic, strong) UIScrollView *contentView;
@property (nonatomic, strong) UIButton *toggleButton;
@property (nonatomic, strong) NSString *currentTab;
@end

@implementation CosmicMenuWindow

- (instancetype)init {
    self = [super initWithFrame:[UIScreen mainScreen].bounds];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = YES;

        UIViewController *rootVC = [[UIViewController alloc] init];
        rootVC.view.backgroundColor = [UIColor clearColor];
        rootVC.view.userInteractionEnabled = NO;
        self.rootViewController = rootVC;

        self.windowLevel = UIWindowLevelAlert + 2.0;
        self.hidden = NO;
        self.currentTab = @"CHEATS";

        [self createFloatingButton];
        [self createCosmicMenu];
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView == self || hitView == self.rootViewController.view) {
        return nil;
    }
    return hitView;
}

- (void)createFloatingButton {
    self.toggleButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.toggleButton.frame = CGRectMake(40, 100, 60, 60);
    self.toggleButton.backgroundColor = [UIColor colorWithRed:0.07 green:0.04 blue:0.22 alpha:0.85];
    self.toggleButton.layer.cornerRadius = 30;
    self.toggleButton.layer.borderWidth = 2;
    self.toggleButton.layer.borderColor = [UIColor colorWithRed:0.00 green:0.80 blue:1.00 alpha:1.0].CGColor;
    [self.toggleButton setTitle:@"🪐" forState:UIControlStateNormal];
    self.toggleButton.titleLabel.font = [UIFont systemFontOfSize:28];

    self.toggleButton.layer.shadowColor = [UIColor colorWithRed:0.50 green:0.00 blue:1.00 alpha:1.0].CGColor;
    self.toggleButton.layer.shadowOffset = CGSizeZero;
    self.toggleButton.layer.shadowOpacity = 0.9;
    self.toggleButton.layer.shadowRadius = 12;

    [self.toggleButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(buttonDragged:)];
    [self.toggleButton addGestureRecognizer:panGesture];
    [self addSubview:self.toggleButton];
}

- (void)buttonDragged:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self];
    gesture.view.center = CGPointMake(gesture.view.center.x + translation.x, gesture.view.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:self];
}

- (void)createCosmicMenu {
    self.menuView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 340, 380)];
    self.menuView.center = CGPointMake([UIScreen mainScreen].bounds.size.width / 2, [UIScreen mainScreen].bounds.size.height / 2);
    self.menuView.backgroundColor = [UIColor colorWithRed:0.04 green:0.02 blue:0.13 alpha:0.92];
    self.menuView.layer.cornerRadius = 16;
    self.menuView.layer.borderWidth = 1.5;
    self.menuView.layer.borderColor = [UIColor colorWithRed:0.38 green:0.00 blue:0.93 alpha:1.0].CGColor;
    self.menuView.hidden = YES;

    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.frame = self.menuView.bounds;
    blurView.layer.cornerRadius = 16;
    blurView.clipsToBounds = YES;
    [self.menuView addSubview:blurView];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 12, 340, 30)];
    titleLabel.text = @"DEVXANTAPERS OS v1.0";
    titleLabel.textColor = [UIColor colorWithRed:0.00 green:0.80 blue:1.00 alpha:1.0];
    titleLabel.font = [UIFont fontWithName:@"CourierNewPS-BoldMT" size:18];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.menuView addSubview:titleLabel];

    UIButton *cheatsTab = [UIButton buttonWithType:UIButtonTypeCustom];
    cheatsTab.frame = CGRectMake(15, 55, 150, 35);
    cheatsTab.backgroundColor = [UIColor colorWithRed:0.09 green:0.05 blue:0.28 alpha:0.7];
    [cheatsTab setTitle:@"MODULES" forState:UIControlStateNormal];
    [cheatsTab setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    cheatsTab.titleLabel.font = [UIFont fontWithName:@"CourierNewPS-BoldMT" size:14];
    cheatsTab.layer.cornerRadius = 6;
    [cheatsTab addTarget:self action:@selector(showCheatsTab) forControlEvents:UIControlEventTouchUpInside];
    [self.menuView addSubview:cheatsTab];

    UIButton *creatorsTab = [UIButton buttonWithType:UIButtonTypeCustom];
    creatorsTab.frame = CGRectMake(175, 55, 150, 35);
    creatorsTab.backgroundColor = [UIColor colorWithRed:0.09 green:0.05 blue:0.28 alpha:0.7];
    [creatorsTab setTitle:@"CREATORS" forState:UIControlStateNormal];
    [creatorsTab setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    creatorsTab.titleLabel.font = [UIFont fontWithName:@"CourierNewPS-BoldMT" size:14];
    creatorsTab.layer.cornerRadius = 6;
    [creatorsTab addTarget:self action:@selector(showCreatorsTab) forControlEvents:UIControlEventTouchUpInside];
    [self.menuView addSubview:creatorsTab];

    self.contentView = [[UIScrollView alloc] initWithFrame:CGRectMake(15, 105, 310, 260)];
    self.contentView.showsVerticalScrollIndicator = NO;
    [self.menuView addSubview:self.contentView];

    [self renderTabs];
    [self addSubview:self.menuView];
}

- (void)toggleMenu { self.menuView.hidden = !self.menuView.hidden; }
- (void)showCheatsTab { self.currentTab = @"CHEATS"; [self renderTabs]; }
- (void)showCreatorsTab { self.currentTab = @"CREATORS"; [self renderTabs]; }

- (void)renderTabs {
    for (UIView *view in self.contentView.subviews) { [view removeFromSuperview]; }

    if ([self.currentTab isEqualToString:@"CHEATS"]) {
        [self createSwitchWithLabel:@"GOD MODE (NO DAMAGE)" yPosition:10 action:@selector(godModeToggled:) isOn:godModeEnabled];
        [self createSwitchWithLabel:@"FREEZE RACE TIME" yPosition:60 action:@selector(timeToggled:) isOn:infiniteTimeEnabled];
        [self createSwitchWithLabel:@"SCORE MULTIPLIER x500" yPosition:110 action:@selector(scoreToggled:) isOn:scoreMultiplierEnabled];
        [self createSwitchWithLabel:@"UNLOCK 1,000,000$ CASH" yPosition:160 action:@selector(moneyToggled:) isOn:moneyHackEnabled];
        self.contentView.contentSize = CGSizeMake(310, 220);

    } else if ([self.currentTab isEqualToString:@"CREATORS"]) {
        UILabel *devLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, 310, 30)];
        devLabel.text = @"DEVELOPED BY XANTAPERS";
        devLabel.textColor = [UIColor whiteColor];
        devLabel.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:16];
        devLabel.textAlignment = NSTextAlignmentCenter;
        [self.contentView addSubview:devLabel];

        UILabel *tgkLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 55, 310, 25)];
        tgkLabel.text = @"Official Telegram Channel Source:";
        tgkLabel.textColor = [UIColor colorWithRed:0.7 green:0.7 blue:0.8 alpha:0.8];
        tgkLabel.font = [UIFont systemFontOfSize:13];
        tgkLabel.textAlignment = NSTextAlignmentCenter;
        [self.contentView addSubview:tgkLabel];

        UIButton *tgButton = [UIButton buttonWithType:UIButtonTypeCustom];
        tgButton.frame = CGRectMake(35, 95, 240, 45);
        tgButton.backgroundColor = [UIColor colorWithRed:0.00 green:0.53 blue:0.82 alpha:1.0];
        [tgButton setTitle:@"@devxantapers" forState:UIControlStateNormal];
        [tgButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        tgButton.titleLabel.font = [UIFont fontWithName:@"CourierNewPS-BoldMT" size:18];
        tgButton.layer.cornerRadius = 8;
        tgButton.layer.shadowColor = [UIColor colorWithRed:0.00 green:0.80 blue:1.00 alpha:1.0].CGColor;
        tgButton.layer.shadowOffset = CGSizeZero;
        tgButton.layer.shadowOpacity = 0.6;
        tgButton.layer.shadowRadius = 8;
        [tgButton addTarget:self action:@selector(openTelegram) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:tgButton];
        self.contentView.contentSize = CGSizeMake(310, 240);
    }
}

- (void)createSwitchWithLabel:(NSString *)labelText yPosition:(CGFloat)y action:(SEL)selector isOn:(BOOL)status {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(10, y, 220, 30)];
    label.text = labelText;
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont fontWithName:@"CourierNewPS-BoldMT" size:13];
    [self.contentView addSubview:label];

    UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectMake(240, y, 50, 30)];
    toggle.onTintColor = [UIColor colorWithRed:0.00 green:0.80 blue:1.00 alpha:1.0];
    toggle.thumbTintColor = [UIColor colorWithRed:0.07 green:0.04 blue:0.22 alpha:1.0];
    [toggle setOn:status];
    [toggle addTarget:self action:selector forControlEvents:UIControlEventValueChanged];
    [self.contentView addSubview:toggle];
}

- (void)godModeToggled:(UISwitch *)sender { godModeEnabled = sender.isOn; }
- (void)timeToggled:(UISwitch *)sender { infiniteTimeEnabled = sender.isOn; }
- (void)scoreToggled:(UISwitch *)sender { scoreMultiplierEnabled = sender.isOn; }
- (void)moneyToggled:(UISwitch *)sender { moneyHackEnabled = sender.isOn; }

- (void)openTelegram {
    NSURL *tgURL = [NSURL URLWithString:@"tg://resolve?domain=devxantapers"];
    if ([[UIApplication sharedApplication] canOpenURL:tgURL]) {
        [[UIApplication sharedApplication] openURL:tgURL options:@{} completionHandler:nil];
    } else {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://t.me/devxantapers"] options:@{} completionHandler:nil];
    }
}

@end

// --- ЗАПУСК: МЕНЮ + УСТАНОВКА ХУКОВ ---

@interface HookManager : NSObject
@end

@implementation HookManager

+ (void)load {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        static CosmicMenuWindow *menuInstance = nil;
        menuInstance = [[CosmicMenuWindow alloc] init];
        install_hooks();
    });
}

@end
