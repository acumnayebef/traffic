#include <substrate.h>
#include <mach-o/dyld.h>
#include <cstring>

// Импортируем флаги управления из main.mm
extern BOOL godModeEnabled;
extern BOOL infiniteTimeEnabled;
extern BOOL scoreMultiplierEnabled;
extern BOOL moneyHackEnabled;

// Вспомогательная функция для динамического поиска базового адреса UnityFramework
uintptr_t get_UnityFramework_BaseAddress() {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "UnityFramework")) {
            return (uintptr_t)_dyld_get_image_header(i);
        }
    }
    // Если игра собрана без внешнего фреймворка, возвращаем адрес основного исполняемого файла
    return (uintptr_t)_dyld_get_image_header(0);
}

// --- 1. МОДУЛЬ: GOD MODE (БЕССМЕРТИЕ) ---
void (*old_HR_PlayerHandler_OnCollisionEnter)(void* instance, void* collision);
void new_HR_PlayerHandler_OnCollisionEnter(void* instance, void* collision) {
    if (godModeEnabled) {
        return; 
    }
    old_HR_PlayerHandler_OnCollisionEnter(instance, collision);
}

// --- 2. МОДУЛЬ: FREEZE TIME (ЗАМОРОЗКА ВРЕМЕНИ) ---
void (*old_HR_PlayerHandler_Update)(void* instance);
void new_HR_PlayerHandler_Update(void* instance) {
    old_HR_PlayerHandler_Update(instance);
    
    if (instance != nullptr && infiniteTimeEnabled) {
        *(float*)((uintptr_t)instance + 0x48) = 99.0f;
    }
}

// --- 3. МОДУЛЬ: SCORE MULTIPLIER (МНОЖИТЕЛЬ ОЧКОВ x500) ---
void (*old_GamePlayScoresManager_Update)(void* instance);
void new_GamePlayScoresManager_Update(void* instance) {
    old_GamePlayScoresManager_Update(instance);
    
    if (instance != nullptr && scoreMultiplierEnabled) {
        *(float*)((uintptr_t)instance + 0x4C) = 500.0f;
    }
}

// --- 4. МОДУЛЬ: 1,000,000$ (ДЕБАГ-ХАК) ---
void (*old_HR_MainMenuHandler_Start)(void* instance);
void new_HR_MainMenuHandler_Start(void* instance) {
    old_HR_MainMenuHandler_Start(instance);
    
    if (moneyHackEnabled) {
        uintptr_t unityBase = get_UnityFramework_BaseAddress();
        void* (*HR_HighwayRacerProperties_get_Instance)() = (void*(*)())(unityBase + 0x3E37DA8);
        void* propertiesAsset = HR_HighwayRacerProperties_get_Instance();
        
        if (propertiesAsset != nullptr) {
            *(bool*)((uintptr_t)propertiesAsset + 0x50) = true;
        }
    }
}

// --- КОНСТРУКТОР СУБСТРАТА ---
static void __attribute__((constructor)) initializeSubstrateHooks() {
    // Получаем корректный адрес Unity-движка для сайдлоадинга
    uintptr_t unityBase = get_UnityFramework_BaseAddress();
    
    // 1. Хукаем аварии
    MSHookFunction((void*)(unityBase + 0x3E452A4), 
                   (void*)&new_HR_PlayerHandler_OnCollisionEnter, 
                   (void**)&old_HR_PlayerHandler_OnCollisionEnter);
                   
    // 2. Хукаем таймер
    MSHookFunction((void*)(unityBase + 0x3E443E0), 
                   (void*)&new_HR_PlayerHandler_Update, 
                   (void**)&old_HR_PlayerHandler_Update);
                   
    // 3. Хукаем множитель комбо
    MSHookFunction((void*)(unityBase + 0x3BA37D8), 
                   (void*)&new_GamePlayScoresManager_Update, 
                   (void**)&old_GamePlayScoresManager_Update);
                   
    // 4. Хукаем скрытый миллион в меню
    MSHookFunction((void*)(unityBase + 0x3E3CF58), 
                   (void*)&new_HR_MainMenuHandler_Start, 
                   (void**)&old_HR_MainMenuHandler_Start);
}
