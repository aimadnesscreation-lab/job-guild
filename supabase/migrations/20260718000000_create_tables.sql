-- Phase 1: Supabase Database Schema Setup
-- Project: Local Services Marketplace App (Pakistan)

-- 1. Enable PostGIS for location-based queries
CREATE EXTENSION IF NOT EXISTS postgis;

-- 2. Create Users Table (extends Supabase Auth)
CREATE TABLE IF NOT EXISTS public.users (
    id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
    phone_number TEXT UNIQUE NOT NULL,
    email TEXT,
    full_name TEXT NOT NULL,
    profile_photo_url TEXT,
    city TEXT,
    current_location GEOGRAPHY(POINT, 4326),
    preferred_language TEXT DEFAULT 'en' CHECK (preferred_language IN ('en', 'ur')),
    is_verified BOOLEAN DEFAULT FALSE,
    id_verification_status TEXT DEFAULT 'none' CHECK (id_verification_status IN ('none', 'pending', 'verified')),
    account_status TEXT DEFAULT 'active' CHECK (account_status IN ('active', 'suspended')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Create Categories Table
CREATE TABLE IF NOT EXISTS public.categories (
    id SERIAL PRIMARY KEY,
    name_en TEXT NOT NULL,
    name_ur TEXT NOT NULL,
    parent_id INTEGER REFERENCES public.categories(id),
    icon_name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Create Worker Profiles Table
CREATE TABLE IF NOT EXISTS public.worker_profiles (
    id UUID REFERENCES public.users(id) ON DELETE CASCADE PRIMARY KEY,
    headline TEXT,
    bio TEXT,
    years_experience INTEGER DEFAULT 0,
    hourly_rate_pkr INTEGER,
    fixed_rate_note TEXT,
    availability_status TEXT DEFAULT 'offline' CHECK (availability_status IN ('today', 'tomorrow', 'weekdays', 'weekends', 'morning', 'evening', 'busy', 'offline')),
    service_radius_km INTEGER DEFAULT 10,
    average_rating DECIMAL(3, 2) DEFAULT 0,
    total_jobs_completed INTEGER DEFAULT 0,
    response_time_avg_minutes INTEGER DEFAULT 0,
    portfolio_media TEXT[], -- Array of GCS/Supabase Storage URLs
    is_featured BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Create Worker Category Junction Table
CREATE TABLE IF NOT EXISTS public.worker_categories (
    worker_id UUID REFERENCES public.worker_profiles(id) ON DELETE CASCADE,
    category_id INTEGER REFERENCES public.categories(id) ON DELETE CASCADE,
    PRIMARY KEY (worker_id, category_id)
);

-- 6. Create Jobs Table
CREATE TABLE IF NOT EXISTS public.jobs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    employer_id UUID REFERENCES public.users(id) NOT NULL,
    category_id INTEGER REFERENCES public.categories(id) NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    ai_extracted_metadata JSONB, -- { "urgency": "...", "suggested_budget": ..., "skills": [...] }
    budget_amount INTEGER,
    budget_type TEXT DEFAULT 'negotiable' CHECK (budget_type IN ('fixed', 'hourly', 'negotiable')),
    location_text TEXT,
    location_coords GEOGRAPHY(POINT, 4326) NOT NULL,
    status TEXT DEFAULT 'open' CHECK (status IN ('open', 'hired', 'completed', 'cancelled', 'expired')),
    urgency TEXT DEFAULT 'today' CHECK (urgency IN ('instant', 'today', 'scheduled')),
    scheduled_for TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Create Job Applications Table
CREATE TABLE IF NOT EXISTS public.applications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    job_id UUID REFERENCES public.jobs(id) ON DELETE CASCADE NOT NULL,
    worker_id UUID REFERENCES public.worker_profiles(id) ON DELETE CASCADE NOT NULL,
    status TEXT DEFAULT 'interested' CHECK (status IN ('interested', 'shortlisted', 'hired', 'rejected', 'completed')),
    message TEXT,
    applied_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(job_id, worker_id)
);

-- 8. Create Messages Table
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    job_id UUID REFERENCES public.jobs(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES public.users(id) NOT NULL,
    content_type TEXT DEFAULT 'text' CHECK (content_type IN ('text', 'image', 'voice', 'location', 'file')),
    content TEXT NOT NULL,
    sent_at TIMESTAMPTZ DEFAULT NOW(),
    read_at TIMESTAMPTZ
);

-- 9. Create Reviews Table
CREATE TABLE IF NOT EXISTS public.reviews (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    job_id UUID REFERENCES public.jobs(id) NOT NULL,
    reviewer_id UUID REFERENCES public.users(id) NOT NULL,
    reviewee_id UUID REFERENCES public.users(id) NOT NULL,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(job_id, reviewer_id, reviewee_id)
);

-- 10. Create Notifications Table
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    type TEXT NOT NULL,
    payload JSONB,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security (RLS)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.worker_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.worker_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- Users: Anyone can view profiles, only owner can edit
CREATE POLICY "Public profiles are viewable by everyone" ON public.users FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON public.users FOR UPDATE USING (auth.uid() = id);

-- Worker Profiles: Viewable by all, only owner can edit
CREATE POLICY "Worker profiles are viewable by everyone" ON public.worker_profiles FOR SELECT USING (true);
CREATE POLICY "Workers can update own profile" ON public.worker_profiles FOR UPDATE USING (auth.uid() = id);

-- Categories: Read-only for everyone
CREATE POLICY "Categories are viewable by everyone" ON public.categories FOR SELECT USING (true);

-- Jobs: Viewable by all, only owner can edit
CREATE POLICY "Jobs are viewable by everyone" ON public.jobs FOR SELECT USING (true);
CREATE POLICY "Employers can insert jobs" ON public.jobs FOR INSERT WITH CHECK (auth.uid() = employer_id);
CREATE POLICY "Employers can update own jobs" ON public.jobs FOR UPDATE USING (auth.uid() = employer_id);

-- Applications: Employer and Applicant can view
CREATE POLICY "Applicant can view own application" ON public.applications FOR SELECT USING (auth.uid() = worker_id);
CREATE POLICY "Employer can view applications for own job" ON public.applications FOR SELECT USING (EXISTS (SELECT 1 FROM public.jobs WHERE id = job_id AND employer_id = auth.uid()));
CREATE POLICY "Workers can apply to jobs" ON public.applications FOR INSERT WITH CHECK (auth.uid() = worker_id);

-- Messages: Only participants can view/insert
CREATE POLICY "Participants can view messages" ON public.messages FOR SELECT USING (
    auth.uid() = sender_id OR 
    EXISTS (SELECT 1 FROM public.jobs WHERE id = job_id AND employer_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.applications WHERE job_id = public.messages.job_id AND worker_id = auth.uid() AND status = 'hired')
);
CREATE POLICY "Participants can insert messages" ON public.messages FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- Reviews: Viewable by all, insertable by job participants
CREATE POLICY "Reviews are viewable by everyone" ON public.reviews FOR SELECT USING (true);
CREATE POLICY "Participants can review each other" ON public.reviews FOR INSERT WITH CHECK (
    auth.uid() = reviewer_id AND 
    EXISTS (SELECT 1 FROM public.jobs WHERE id = job_id AND (employer_id = auth.uid() OR EXISTS (SELECT 1 FROM public.applications WHERE job_id = public.reviews.job_id AND worker_id = auth.uid() AND status = 'hired')))
);

-- Notifications: Only owner can view/update
CREATE POLICY "Users can view own notifications" ON public.notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update own notifications" ON public.notifications FOR UPDATE USING (auth.uid() = user_id);

-- Seed Data: Categories
INSERT INTO public.categories (name_en, name_ur, icon_name) VALUES
('Home', 'گھر', 'home'),
('Vehicles', 'گاڑیاں', 'directions_car'),
('Construction', 'تعمیرات', 'construction'),
('Education', 'تعلیم', 'school'),
('Technology', 'ٹیکنالوجی', 'computer'),
('Events', 'تقریبات', 'event'),
('Cleaning', 'صفائی', 'cleaning_services'),
('Moving', 'نقل مکانی', 'local_shipping'),
('Healthcare', 'صحت', 'medical_services'),
('Beauty', 'خوبصورتی', 'content_cut'),
('Pet Care', 'پالتو جانوروں کی دیکھ بھال', 'pets'),
('General Labor', 'عام مزدوری', 'work');

-- Subcategories
INSERT INTO public.categories (name_en, name_ur, parent_id) VALUES
('Plumbing', 'پلمبنگ', 1),
('Electrical', 'الیکٹریکل', 1),
('Painting', 'پینٹنگ', 1),
('Carpentry', 'بڑھئی کا کام', 1),
('Masonry', 'مستری کا کام', 1),
('Mechanic', 'مکینک', 2),
('Bike Repair', 'بائیک کی مرمت', 2),
('Car Wash', 'کار واش', 2),
('Labor', 'مزدور', 3),
('Welding', 'ویلڈنگ', 3),
('Steel Fixing', 'سٹیل فکسنگ', 3),
('Tutor', 'ٹیوٹر', 4),
('Language Teacher', 'زبان کا استاد', 4),
('Laptop Repair', 'لیپ ٹاپ کی مرمت', 5),
('Mobile Repair', 'موبائل کی مرمت', 5),
('Web Developer', 'ویب ڈویلپر', 5),
('Photographer', 'فوٹوگرافر', 6),
('DJ', 'ڈی جے', 6),
('Cook', 'باورچی', 6);

-- RPC for nearby jobs
CREATE OR REPLACE FUNCTION get_nearby_jobs(lat float, lng float, radius_km float)
RETURNS SETOF jobs AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM jobs
  WHERE st_dwithin(
    location_coords,
    st_setsrid(st_makepoint(lng, lat), 4326)::geography,
    radius_km * 1000
  )
  ORDER BY location_coords <-> st_setsrid(st_makepoint(lng, lat), 4326)::geography;
END;
$$ LANGUAGE plpgsql;

-- RPC for nearby workers
CREATE OR REPLACE FUNCTION get_nearby_workers(lat float, lng float, radius_km float)
RETURNS TABLE (
    id UUID,
    full_name TEXT,
    profile_photo_url TEXT,
    headline TEXT,
    bio TEXT,
    average_rating DECIMAL,
    total_jobs_completed INTEGER,
    distance_meters FLOAT,
    availability TEXT,
    category TEXT,
    is_verified BOOLEAN,
    hourly_rate_pkr INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.id, 
    u.full_name, 
    u.profile_photo_url, 
    wp.headline, 
    wp.bio, 
    wp.average_rating, 
    wp.total_jobs_completed,
    st_distance(u.current_location, st_setsrid(st_makepoint(lng, lat), 4326)::geography) as distance_meters,
    wp.availability_status as availability,
    (SELECT c.name_en FROM worker_categories wc JOIN categories c ON wc.category_id = c.id WHERE wc.worker_id = wp.id LIMIT 1) as category,
    u.is_verified,
    wp.hourly_rate_pkr
  FROM users u
  JOIN worker_profiles wp ON u.id = wp.id
  WHERE u.current_location IS NOT NULL
  AND st_dwithin(
    u.current_location,
    st_setsrid(st_makepoint(lng, lat), 4326)::geography,
    radius_km * 1000
  )
  ORDER BY distance_meters;
END;
$$ LANGUAGE plpgsql;


